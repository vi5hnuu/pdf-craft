import 'dart:io';

import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/singletons/file_store.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/file_actions_sheet.dart';
import 'package:pdf_craft/widgets/file_tile.dart';
import 'package:pdf_craft/widgets/skeleton_list.dart';
import 'package:pdf_craft/widgets/confirm_dialog.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';

/// "Results" hub — every file a tool has produced, in one place.
///
/// Tools save their output to [Constants.processedDirPath]; this screen lists
/// those outputs (newest first) with open / share / save-as / delete actions so
/// users never have to hunt through the file manager for what they just made.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  /// Row index the inline ad occupies. Far enough down that the first screenful is all results.
  static const _adAfterRow = 4;

  List<File>? _files; // null while loading

  @override
  void initState() {
    super.initState();
    _load();
    // Deleting or renaming elsewhere (the file actions sheet, the preview screen)
    // used to leave this list showing files that no longer exist.
    FileStore().addListener(_onFilesChanged);
  }

  @override
  void dispose() {
    FileStore().removeListener(_onFilesChanged);
    super.dispose();
  }

  void _onFilesChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final dir = Directory(Constants.processedDirPath);
    if (!await dir.exists()) {
      if (mounted) setState(() => _files = []);
      return;
    }
    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    // Stat each file once, asynchronously, then sort newest first by the cached times. The
    // comparator used to call statSync() twice per comparison — O(n log n) blocking file-system
    // calls on the UI thread, which stalled the screen with many results.
    final modified = <String, DateTime>{};
    await Future.wait(files.map((f) async {
      try {
        modified[f.path] = (await f.stat()).modified;
      } catch (_) {
        modified[f.path] = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }));
    files.sort((a, b) => modified[b.path]!.compareTo(modified[a.path]!));
    if (mounted) setState(() => _files = files);
  }

  void _open(File file) {
    if (Utility.isPdf(file.path)) {
      GoRouter.of(context).pushNamed(
        AppRoutes.pdfFilePreviewRoute.name,
        pathParameters: {'pdfFilePath': file.path},
      );
    } else {
      final ext = Utility.fileExtension(file);
      OpenFile.open(file.path, type: Constants.extrnalOpenSupportedFiles[ext] ?? '*/*');
    }
  }

  Future<void> _delete(File file) async {
    // The trash icon sits one thumb-width from the favourite star and the deletion is permanent,
    // so it asks first — the same guard the file listings and "clear all" already use.
    final confirm = await ConfirmDialog.show(
      context,
      title: L10n.current.deleteFileTitle,
      message: L10n.current.confirmDeleteFile(file.path.split('/').last),
      confirmLabel: L10n.current.delete,
      destructive: true,
    );
    if (!confirm.confirmed) return;
    try {
      await file.delete();
    } catch (e) {
      // Silently swallowed before: the list reloaded with the file still in it, so confirming a
      // delete and watching nothing happen read as a broken button.
      LoggerSingleton().logger.w('Delete failed for ${file.path}: $e');
      NotificationService.showSnackbar(
          text: L10n.current.errDeleteFailed(file.path.split('/').last),
          color: Colors.red);
    }
    // The FileStore listener reloads this list, and every other listing too.
    FileStore().changed();
  }

  Future<void> _clearAll() async {
    final count = _files?.length ?? 0;
    if (count == 0) return;
    // Through the shared dialog rather than a hand-rolled one, so a destructive confirm looks
    // the same wherever it appears: warning icon, filled red button — not red text on a flat
    // TextButton that carries no more weight than Cancel beside it.
    final confirm = await ConfirmDialog.show(
      context,
      title: L10n.current.resultsClearTitle,
      message: L10n.current.resultsClearBody(count),
      confirmLabel: L10n.current.delete,
      destructive: true,
    );
    if (!confirm.confirmed) return;
    for (final f in List<File>.from(_files ?? const [])) {
      try {
        await f.delete();
      } catch (_) {}
    }
    FileStore().changed();
    NotificationService.showSnackbar(text: L10n.current.resultsCleared, color: Colors.orange);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = _files;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).resultsTitle),
        actions: [
          if (files != null && files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: L10n.of(context).clearAll,
              onPressed: _clearAll,
            ),
        ],
      ),
      body: files == null
          ? const SkeletonList()
          : files.isEmpty
              ? _buildEmpty(theme)
              : RefreshIndicator(
                  onRefresh: _load,
                  // One inline unit after the first handful of rows, so it reads as a row in
                  // a list the user is already scrolling rather than an interruption. Placed
                  // only once, and only when the list is long enough for it not to dominate.
                  child: ListView.builder(
                    itemCount: files.length + (files.length >= _adAfterRow ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (files.length >= _adAfterRow && index == _adAfterRow) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: BannerAdd(),
                        );
                      }
                      final file = files[
                          files.length >= _adAfterRow && index > _adAfterRow ? index - 1 : index];
                      return FileTile(
                        // Keyed by path so the element follows the file, not the row index.
                        key: ValueKey(file.path),
                        file: file,
                        onPress: () => _open(file),
                        onLongPress: () => FileActionsSheet.show(context, file, onChanged: _load),
                        onDelete: () => _delete(file),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(L10n.of(context).resultsEmpty, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              L10n.of(context).resultsEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}
