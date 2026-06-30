import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/get-bookmarks.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/apis/PdfService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/PrefFlags.dart';
import 'package:pdf_craft/widgets/ConfirmDialog.dart';
import 'package:pdf_craft/widgets/InputDialog.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

class PdfPreview extends StatefulWidget {
  final String pdfFilePath;
  final String? password;

  const PdfPreview({super.key, required this.pdfFilePath, this.password});

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  PdfControllerPinch? _controller;
  String? _password;
  bool _loadError = false;
  bool _nightMode = false;
  // Mutable so a rename can update the open file in place.
  late String _path = widget.pdfFilePath;

  // Inverts RGB channels while keeping alpha — turns white pages dark for night reading
  static const _invertMatrix = <double>[
    -1,  0,  0,  0, 255,
     0, -1,  0,  0, 255,
     0,  0, -1,  0, 255,
     0,  0,  0,  1,   0,
  ];

  // Identity — no-op filter used so PdfViewPinch stays in the widget tree when night mode is off
  static const _identityMatrix = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  String get _fileName => _path.split('/').last;

  @override
  void initState() {
    super.initState();
    _password = widget.password;
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    _controller?.dispose();
    setState(() {
      _controller = null;
      _loadError = false;
    });
    try {
      final doc = await PdfDocument.openFile(_path, password: _password);
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(
          viewportFraction: 1,
          document: Future.value(doc),
          initialPage: 1,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName, overflow: TextOverflow.ellipsis),
        actions: [
          // Page indicator — tapping it opens a jump-to-page dialog
          if (_controller != null)
            ValueListenableBuilder<int?>(
              valueListenable: _controller!.pageListenable,
              builder: (context, page, _) {
                final total = _controller!.pagesCount;
                if (total == null) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => _showJumpToPageDialog(total),
                  child: Text(
                    '${page ?? 1} / $total',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                );
              },
            ),
          // Outline / bookmarks — reads the PDF's embedded outline so bookmarks
          // added via the Bookmarks tool are actually visible and navigable here.
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.list_alt_outlined),
              tooltip: 'Bookmarks',
              onPressed: _showOutline,
            ),
          IconButton(
            icon: Icon(_nightMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: _nightMode ? 'Day mode' : 'Night mode',
            onPressed: () => setState(() => _nightMode = !_nightMode),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Upload to Drive',
            onPressed: _uploadToDrive,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => Share.shareXFiles([XFile(_path)]),
          ),
          // Our in-app viewer is intentionally lightweight; offer a way out to
          // a full external PDF viewer at any time (not just on error).
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'external':
                  _openExternally();
                case 'rename':
                  _rename();
                case 'save_copy':
                  _saveCopyToDownloads();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.drive_file_rename_outline),
                  title: Text('Rename'),
                ),
              ),
              PopupMenuItem(
                value: 'save_copy',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.download_outlined),
                  title: Text('Save a copy to Downloads'),
                ),
              ),
              PopupMenuItem(
                value: 'external',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.open_in_new),
                  title: Text('Open in external viewer'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(theme, primary),
    );
  }

  Widget _buildBody(ThemeData theme, Color primary) {
    // Show error state (password prompt or generic error)
    if (_loadError) {
      return _ErrorState(
        filePath: _path,
        onRetryWithPassword: () => _askForPasswordAndRetry(context),
      );
    }

    // Loading — controller not yet assigned
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final viewer = PdfViewPinch(
      controller: _controller!,
      padding: 16,
      minScale: 1,
      maxScale: 10,
      scrollDirection: Axis.vertical,
      backgroundDecoration: BoxDecoration(
        color: _nightMode ? Colors.black : const Color(0xFFEEEEEE),
      ),
      onDocumentError: (_) => _askForPasswordAndRetry(context),
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: DefaultBuilderOptions(
          loaderSwitchDuration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
        ),
        documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, error) => _ErrorState(
          filePath: _path,
          onRetryWithPassword: () => _askForPasswordAndRetry(context),
        ),
      ),
    );

    // Always wrap in ColorFiltered so PdfViewPinch is never disposed/recreated on toggle
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_nightMode ? _invertMatrix : _identityMatrix),
      child: viewer,
    );
  }

  void _openExternally() {
    final ext = '.${_path.split('.').last}';
    OpenFile.open(_path,
        type: Constants.extrnalOpenSupportedFiles[ext] ?? '*/*');
  }

  /// Renames the open file on disk and keeps viewing it under the new name.
  Future<void> _rename() async {
    final name = _fileName;
    final dot = name.lastIndexOf('.');
    final base = dot == -1 ? name : name.substring(0, dot);
    final ext = dot == -1 ? '' : name.substring(dot);

    final newBase = await InputDialog.show(
      context,
      title: 'Rename file',
      label: 'New name',
      initial: base,
      confirmLabel: 'Rename',
    );
    if (newBase == null || newBase.trim().isEmpty || newBase.trim() == base) return;

    final dir = File(_path).parent.path;
    final newPath = '$dir/${newBase.trim()}$ext';
    if (File(newPath).existsSync()) {
      NotificationService.showSnackbar(text: 'A file with that name already exists', color: Colors.red);
      return;
    }
    try {
      await File(_path).rename(newPath);
      if (!mounted) return;
      setState(() => _path = newPath);
      NotificationService.showSnackbar(text: 'Renamed', color: Colors.green);
    } catch (_) {
      NotificationService.showSnackbar(text: 'Could not rename file', color: Colors.red);
    }
  }

  /// Copies the open file into the device Downloads folder for easy retrieval.
  Future<void> _saveCopyToDownloads() async {
    try {
      final dir = Directory(Constants.downloadsStoragePath);
      if (!dir.existsSync()) await dir.create(recursive: true);
      // Avoid clobbering an existing download with the same name.
      var dest = '${dir.path}/$_fileName';
      if (File(dest).existsSync()) {
        final name = _fileName;
        final dot = name.lastIndexOf('.');
        final base = dot == -1 ? name : name.substring(0, dot);
        final ext = dot == -1 ? '' : name.substring(dot);
        dest = '${dir.path}/$base-${DateTime.now().millisecondsSinceEpoch}$ext';
      }
      await File(_path).copy(dest);
      NotificationService.showSnackbar(text: 'Saved to Downloads', color: Colors.green);
    } catch (_) {
      NotificationService.showSnackbar(text: 'Could not save to Downloads', color: Colors.red);
    }
  }

  /// Explains what uploading does before navigating to the Drive screen, with a
  /// "don't ask again" option so power users aren't nagged.
  Future<void> _uploadToDrive() async {
    final skip = await PrefFlags.isSet(PrefFlags.skipDriveUploadInfo);
    if (!mounted) return;
    if (!skip) {
      final result = await ConfirmDialog.show(
        context,
        title: 'Upload to Google Drive',
        message:
            'A copy of this PDF will be uploaded to your Google Drive (in a "PDF Craft" folder). You can review or switch your account on the next screen.',
        confirmLabel: 'Continue',
        icon: Icons.cloud_upload_outlined,
        showDontAskAgain: true,
      );
      if (!result.confirmed) return;
      if (result.dontAskAgain) {
        await PrefFlags.set(PrefFlags.skipDriveUploadInfo, true);
      }
    }
    if (!mounted) return;
    GoRouter.of(context).pushNamed(
      AppRoutes.driveRoute.name,
      extra: {'file': File(_path)},
    );
  }

  Future<void> _askForPasswordAndRetry(BuildContext context) async {
    final newPassword = await InputDialog.show(
      context,
      title: 'Password Required',
      label: 'Enter PDF password',
      obscure: true,
      confirmLabel: 'Open',
    );
    if (newPassword != null) {
      _password = newPassword.isEmpty ? null : newPassword;
      await _loadDocument();
    }
  }

  /// Opens a bottom sheet listing the PDF's embedded outline (bookmarks).
  /// Tapping an entry jumps the viewer to that page.
  Future<void> _showOutline() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _OutlineSheet(
        filePath: _path,
        onJump: (pageIndex) {
          Navigator.pop(context);
          _controller?.jumpToPage(pageIndex + 1); // controller is 1-indexed
        },
      ),
    );
  }

  Future<void> _showJumpToPageDialog(int totalPages) async {
    final input = await InputDialog.show(
      context,
      title: 'Go to Page',
      hint: '1 – $totalPages',
      keyboardType: TextInputType.number,
      confirmLabel: 'Go',
    );
    if (input == null) return;
    final page = int.tryParse(input);
    if (page == null || page < 1 || page > totalPages) return;
    _controller?.jumpToPage(page);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Fetches and renders the PDF's embedded outline (bookmarks) in a bottom sheet.
/// Bookmarks live inside the PDF, so they're read server-side via get-bookmarks.
class _OutlineSheet extends StatefulWidget {
  final String filePath;
  final void Function(int pageIndex) onJump;

  const _OutlineSheet({required this.filePath, required this.onJump});

  @override
  State<_OutlineSheet> createState() => _OutlineSheetState();
}

class _OutlineSheetState extends State<_OutlineSheet> {
  late Future<List<_OutlineItem>> _future = _load();

  Future<List<_OutlineItem>> _load() async {
    final file = await MultipartFile.fromFile(widget.filePath);
    final res = await PdfService().getBookmarks(req: GetBookmarks(file: file));
    final data = res.data;
    final out = <_OutlineItem>[];
    if (data is List) _flatten(data, 0, out);
    return out;
  }

  void _flatten(List<dynamic> raw, int depth, List<_OutlineItem> into) {
    for (final item in raw) {
      if (item is! Map) continue;
      into.add(_OutlineItem(
        title: (item['title'] as String?)?.trim().isNotEmpty == true ? item['title'] as String : 'Untitled',
        pageIndex: (item['pageIndex'] as num?)?.toInt() ?? 0,
        depth: depth,
      ));
      final children = item['children'];
      if (children is List && children.isNotEmpty) _flatten(children, depth + 1, into);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Icon(Icons.bookmark_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Bookmarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<_OutlineItem>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data ?? const [];
                  if (snap.hasError || items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'This PDF has no bookmarks.\nAdd some with the Bookmarks tool.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.only(left: 16 + item.depth * 18.0, right: 16),
                        leading: Icon(Icons.bookmark_outline, size: 18, color: theme.colorScheme.primary),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text('p.${item.pageIndex + 1}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        onTap: () => widget.onJump(item.pageIndex),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OutlineItem {
  final String title;
  final int pageIndex;
  final int depth;
  _OutlineItem({required this.title, required this.pageIndex, required this.depth});
}

class _ErrorState extends StatelessWidget {
  final String filePath;
  final VoidCallback onRetryWithPassword;

  const _ErrorState({required this.filePath, required this.onRetryWithPassword});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final ext = '.${filePath.split('.').last}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lightweight vector icon instead of a heavy Lottie animation.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 44, color: primary),
            ),
            const SizedBox(height: 20),
            Text(
              'This PDF is locked',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              "It looks password-protected or couldn't be opened. Enter the "
              'password to view it here, or open it in another app.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            // Full-width stacked buttons — robust on narrow screens.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Enter password'),
                onPressed: onRetryWithPassword,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open in another app'),
                onPressed: () => OpenFile.open(
                  filePath,
                  type: Constants.extrnalOpenSupportedFiles[ext] ?? '*/*',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
