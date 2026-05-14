import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Compares two PDF files side-by-side or as an overlay blend.
class PdfCompareView extends StatefulWidget {
  final File file1;
  final File file2;

  const PdfCompareView({super.key, required this.file1, required this.file2});

  @override
  State<PdfCompareView> createState() => _PdfCompareViewState();
}

enum _CompareMode { sideBySide, overlay }

class _PdfCompareViewState extends State<PdfCompareView> {
  PdfController? _ctrl1;
  PdfController? _ctrl2;

  PdfDocument? _doc1;
  PdfDocument? _doc2;

  PdfPageImage? _overlayImg1;
  PdfPageImage? _overlayImg2;
  bool _loadingOverlay = false;

  _CompareMode _mode = _CompareMode.sideBySide;
  double _blendOpacity = 0.5;
  int _currentPage = 1;
  int _totalPages1 = 0;
  int _totalPages2 = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      _doc1 = await PdfDocument.openFile(widget.file1.path);
      _doc2 = await PdfDocument.openFile(widget.file2.path);
      _ctrl1 = PdfController(document: PdfDocument.openFile(widget.file1.path));
      _ctrl2 = PdfController(document: PdfDocument.openFile(widget.file2.path));
      if (mounted) {
        setState(() {
          _totalPages1 = _doc1!.pagesCount;
          _totalPages2 = _doc2!.pagesCount;
        });
        await _loadOverlayImages();
      }
    } catch (_) {}
  }

  Future<void> _loadOverlayImages() async {
    if (_doc1 == null || _doc2 == null) return;
    setState(() => _loadingOverlay = true);
    try {
      final page1 = await _doc1!.getPage(_currentPage);
      final page2 = await _doc2!.getPage(_currentPage);
      final img1 = await page1.render(width: page1.width * 2, height: page1.height * 2, format: PdfPageImageFormat.jpeg);
      final img2 = await page2.render(width: page2.width * 2, height: page2.height * 2, format: PdfPageImageFormat.jpeg);
      await page1.close();
      await page2.close();
      if (mounted) setState(() { _overlayImg1 = img1; _overlayImg2 = img2; _loadingOverlay = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingOverlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name1 = widget.file1.path.split('/').last;
    final name2 = widget.file2.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare PDFs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<_CompareMode>(
              segments: const [
                ButtonSegment(value: _CompareMode.sideBySide, label: Text('Side by Side'), icon: Icon(Icons.view_agenda_outlined)),
                ButtonSegment(value: _CompareMode.overlay, label: Text('Overlay'), icon: Icon(Icons.layers_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() => _mode = s.first);
                if (_mode == _CompareMode.overlay) _loadOverlayImages();
              },
            ),
          ),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _mode == _CompareMode.sideBySide
              ? _buildSideBySide(theme, name1, name2)
              : _buildOverlay(theme),
        ),
        if (_mode == _CompareMode.overlay)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('Doc 1', style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: _blendOpacity,
                  onChanged: (v) => setState(() => _blendOpacity = v),
                ),
              ),
              Text('Doc 2', style: theme.textTheme.bodySmall),
            ]),
          ),
        _buildPageNav(theme),
      ]),
    );
  }

  Widget _buildSideBySide(ThemeData theme, String name1, String name2) {
    if (_ctrl1 == null || _ctrl2 == null) return const Center(child: CircularProgressIndicator());
    return Row(children: [
      Expanded(
        child: Column(children: [
          _fileLabel(theme, name1),
          Expanded(
            child: PdfView(controller: _ctrl1!),
          ),
        ]),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        child: Column(children: [
          _fileLabel(theme, name2),
          Expanded(
            child: PdfView(controller: _ctrl2!),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildOverlay(ThemeData theme) {
    if (_loadingOverlay) return const Center(child: CircularProgressIndicator());
    if (_overlayImg1 == null || _overlayImg2 == null) {
      return const Center(child: Text('Could not load pages for overlay'));
    }
    return Center(
      child: Stack(alignment: Alignment.center, children: [
        Image.memory(_overlayImg1!.bytes, fit: BoxFit.contain),
        Opacity(
          opacity: _blendOpacity,
          child: Image.memory(_overlayImg2!.bytes, fit: BoxFit.contain),
        ),
      ]),
    );
  }

  Widget _fileLabel(ThemeData theme, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
    );
  }

  Widget _buildPageNav(ThemeData theme) {
    final maxPage = _totalPages1 > 0 && _totalPages2 > 0
        ? _totalPages1.compareTo(_totalPages2) <= 0 ? _totalPages1 : _totalPages2
        : 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
        ),
        Text('Page $_currentPage / $maxPage'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < maxPage ? () => _goToPage(_currentPage + 1) : null,
        ),
      ]),
    );
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _ctrl1?.jumpToPage(page);
    _ctrl2?.jumpToPage(page);
    if (_mode == _CompareMode.overlay) _loadOverlayImages();
  }

  @override
  void dispose() {
    _ctrl1?.dispose();
    _ctrl2?.dispose();
    _doc1?.close();
    _doc2?.close();
    super.dispose();
  }
}
