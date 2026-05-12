import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/singletons/RecentFilesService.dart';
import 'package:pdf_craft/utils/Constants.dart';
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

  String get _fileName => widget.pdfFilePath.split('/').last;

  @override
  void initState() {
    super.initState();
    _password = widget.password;
    _loadDocument();
    RecentFilesService().addFile(widget.pdfFilePath);
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
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => Share.shareXFiles([XFile(widget.pdfFilePath)]),
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

    return PdfViewPinch(
      controller: _controller!,
      padding: 16,
      minScale: 1,
      maxScale: 10,
      scrollDirection: Axis.vertical,
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
  }

  Future<void> _askForPasswordAndRetry(BuildContext context) async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Password Required'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter PDF password',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newPassword != null) {
      _password = newPassword.isEmpty ? null : newPassword;
      await _loadDocument();
    }
  }

  void _showJumpToPageDialog(int totalPages) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 – $totalPages',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _jumpToPage(controller.text, totalPages),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _jumpToPage(controller.text, totalPages),
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _jumpToPage(String input, int totalPages) {
    Navigator.pop(context);
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
    final ext = '.${filePath.split('.').last}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              child: LottieBuilder.asset(
                'assets/lottie/error.json',
                fit: BoxFit.fitWidth,
                repeat: false,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not open this file',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'The file may be password-protected or corrupt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Enter Password'),
                  onPressed: onRetryWithPassword,
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Externally'),
                  onPressed: () => OpenFile.open(
                    filePath,
                    type: Constants.extrnalOpenSupportedFiles[ext] ?? '*/*',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
