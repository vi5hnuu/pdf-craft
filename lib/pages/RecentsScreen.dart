import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/RecentFilesService.dart';
import 'package:pdf_craft/widgets/FileActionsSheet.dart';
import 'package:pdf_craft/widgets/FileTile.dart';

/// Full list of recent PDFs, reached via the "See more" action on the Files
/// tab. The home screen only shows a short horizontal preview; this screen
/// lists every recent PDF (most-recent first).
class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen> {
  List<File>? _recents; // null while loading

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Large limit => effectively "all" recent PDFs.
    final files = await RecentFilesService().getRecentFiles(limit: 1000);
    if (mounted) setState(() => _recents = files);
  }

  void _open(File file) {
    GoRouter.of(context).pushNamed(
      AppRoutes.pdfFilePreviewRoute.name,
      pathParameters: {'pdfFilePath': file.path},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recents = _recents;

    return Scaffold(
      appBar: AppBar(title: const Text('Recent Files')),
      body: recents == null
          ? Center(child: SpinKitPulse(color: theme.colorScheme.primary))
          : recents.isEmpty
              ? Center(
                  child: Text(
                    'No recent files',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: recents.length,
                    itemBuilder: (context, index) {
                      final file = recents[index];
                      return FileTile(
                        file: file,
                        onPress: () => _open(file),
                        onLongPress: () =>
                            FileActionsSheet.show(context, file, onChanged: _load),
                      );
                    },
                  ),
                ),
    );
  }
}
