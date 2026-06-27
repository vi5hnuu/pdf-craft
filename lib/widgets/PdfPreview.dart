import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/routes.dart';
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

  String get _fileName => widget.pdfFilePath.split('/').last;

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
      final doc = await PdfDocument.openFile(widget.pdfFilePath, password: _password);
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
            onPressed: () => Share.shareXFiles([XFile(widget.pdfFilePath)]),
          ),
          // Our in-app viewer is intentionally lightweight; offer a way out to
          // a full external PDF viewer at any time (not just on error).
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'external') _openExternally();
            },
            itemBuilder: (_) => const [
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
        filePath: widget.pdfFilePath,
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
          filePath: widget.pdfFilePath,
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
    final ext = '.${widget.pdfFilePath.split('.').last}';
    OpenFile.open(widget.pdfFilePath,
        type: Constants.extrnalOpenSupportedFiles[ext] ?? '*/*');
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
      extra: {'file': File(widget.pdfFilePath)},
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
