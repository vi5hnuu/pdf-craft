import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/models/request/image-studio.dart' show ImageStudioOp;
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  /// Reads the processed folder, returns files sorted newest-first.
  Future<void> _loadRecentFiles() async {
    final dir = Directory(Constants.processedDirPath);
    if (!dir.existsSync()) return;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final p = f.path.toLowerCase();
          return p.endsWith('.pdf') || p.endsWith('.jpg') || p.endsWith('.png');
        })
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (mounted) setState(() => _recentFiles = files.take(20).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final router = GoRouter.of(context);
    const pdf = ['.pdf'];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadRecentFiles,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: const Text('PDF Craft',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              ),
            ),

            // Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Quick Actions',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 92,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _quickAction(context, Icons.merge, 'Merge', Colors.indigo, () =>
                        router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(
                            path: Constants.rootStoragePath, redirectPath: AppRoutes.mergePdfRoute.path,
                            multiSelect: true, minSelection: 2, limitToExtensions: pdf))),
                    _quickAction(context, Icons.call_split, 'Split', Colors.orange, () =>
                        router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(
                            path: Constants.rootStoragePath, redirectPath: AppRoutes.splitPdfRoute.path,
                            multiSelect: false, limitToExtensions: pdf))),
                    _quickAction(context, Icons.compress, 'Compress', Colors.teal, () =>
                        router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(
                            path: Constants.rootStoragePath, redirectPath: AppRoutes.compressPdfRoute.path,
                            multiSelect: false, limitToExtensions: pdf))),
                    _quickAction(context, Icons.draw_outlined, 'Annotate', Colors.deepPurple, () =>
                        router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(
                            path: Constants.rootStoragePath, redirectPath: AppRoutes.annotatePdfRoute.path,
                            multiSelect: false, limitToExtensions: pdf))),
                    _quickAction(context, Icons.image, 'PDF→JPG', Colors.blue, () =>
                        router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(
                            path: Constants.rootStoragePath, redirectPath: AppRoutes.pdfToJpgRoute.path,
                            multiSelect: false, limitToExtensions: pdf))),
                    _quickAction(context, Icons.auto_fix_high, 'Filters', Colors.green, () =>
                        router.pushNamed(AppRoutes.fileManagement.name, extra: FileSelectionConfig(
                            path: Constants.rootStoragePath, redirectPath: AppRoutes.imageStudioRoute.path,
                            multiSelect: false,
                            limitToExtensions: ['.jpg', '.jpeg', '.png', '.bmp'],
                            extra: {'op': ImageStudioOp.filter}))),
                    _quickAction(context, Icons.cloud_outlined, 'Drive', Colors.red, () =>
                        router.pushNamed(AppRoutes.driveRoute.name, extra: {})),
                  ],
                ),
              ),
            ),

            // Recent files header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Row(children: [
                  Text('Recently Processed',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_recentFiles.isNotEmpty)
                    TextButton(onPressed: _loadRecentFiles, child: const Text('Refresh')),
                ]),
              ),
            ),

            if (_recentFiles.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.folder_open_outlined, size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
                    const SizedBox(height: 12),
                    Text('No processed files yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                  ]),
                ),
              )
            else
              SliverList.builder(
                itemCount: _recentFiles.length,
                itemBuilder: (ctx, i) => _recentFileTile(theme, _recentFiles[i]),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _recentFileTile(ThemeData theme, File file) {
    final name = file.path.split('/').last;
    final isPdf = name.toLowerCase().endsWith('.pdf');
    final modified = file.statSync().modified;
    int sizeBytes = 0;
    try { sizeBytes = file.lengthSync(); } catch (_) {}

    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isPdf ? Colors.red.shade100 : Colors.teal.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          color: isPdf ? Colors.red : Colors.teal, size: 20,
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_timeAgo(modified)} · ${Utility.bytesToSize(sizeBytes)}',
          style: theme.textTheme.bodySmall),
      onTap: isPdf
          ? () => GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,
              pathParameters: {'pdfFilePath': file.path})
          : null,
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
