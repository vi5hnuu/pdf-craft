import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/FileActionsSheet.dart';
import 'package:pdf_craft/widgets/FileTile.dart';

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
    if (!dir.existsSync()) {
      if (mounted) setState(() => _files = []);
      return;
    }
    final files = dir.listSync().whereType<File>().toList();
    // Newest first by modified time.
    files.sort((a, b) {
      try {
        return b.statSync().modified.compareTo(a.statSync().modified);
      } catch (_) {
        return 0;
      }
    });
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
        title: const Text('Clear results'),
        content: Text('Delete all $count output files? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
    NotificationService.showSnackbar(text: 'Results cleared', color: Colors.orange);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = _files;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          if (files != null && files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: files == null
          ? Center(child: SpinKitPulse(color: theme.colorScheme.primary))
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
          const Text('No results yet', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Files you create with any tool will appear here for quick access.',
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
