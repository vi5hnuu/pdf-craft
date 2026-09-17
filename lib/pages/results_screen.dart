import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/file_actions_sheet.dart';
import 'package:pdf_craft/widgets/file_tile.dart';
import 'package:pdf_craft/widgets/skeleton_list.dart';

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
  List<File>? _files; // null while loading

  @override
  void initState() {
    super.initState();
    _load();
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
    try {
      await file.delete();
    } catch (_) {}
    await _load();
  }

  Future<void> _clearAll() async {
    final count = _files?.length ?? 0;
    if (count == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).resultsClearTitle),
        content: Text(L10n.of(ctx).resultsClearBody(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(ctx).cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(ctx).delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    for (final f in List<File>.from(_files ?? const [])) {
      try {
        await f.delete();
      } catch (_) {}
    }
    await _load();
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
                  child: ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return FileTile(
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
