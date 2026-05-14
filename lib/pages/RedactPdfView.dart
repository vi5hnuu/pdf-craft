import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/redact-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

class RedactPdfView extends StatefulWidget {
  final File file;
  const RedactPdfView({super.key, required this.file});

  @override
  State<RedactPdfView> createState() => _RedactPdfViewState();
}

class _RedactPdfViewState extends State<RedactPdfView> {
  PdfDocument? _doc;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfPageImage? _pageImage;
  double _pageWidthPt = 595;
  double _pageHeightPt = 842;
  bool _loadingPage = true;

  // Per-page list of confirmed redact regions (in canvas coords)
  final Map<int, List<_RedactRect>> _pageRects = {};
  List<_RedactRect> get _rects => _pageRects[_currentPage] ??= [];

  // Current drag state
  Offset? _dragStart;
  Offset? _dragEnd;

  // Canvas dimensions from LayoutBuilder
  double _lastImgW = 0;
  double _lastImgH = 0;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _openDocument();
  }

  Future<void> _openDocument() async {
    try {
      _doc = await PdfDocument.openFile(widget.file.path);
      _totalPages = _doc!.pagesCount;
      await _loadPage(_currentPage);
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  Future<void> _loadPage(int pageNo) async {
    if (_doc == null) return;
    setState(() => _loadingPage = true);
    try {
      final page = await _doc!.getPage(pageNo);
      _pageWidthPt = page.width;
      _pageHeightPt = page.height;
      final img = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      if (!mounted) return;
      setState(() { _pageImage = img; _currentPage = pageNo; _loadingPage = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Redact PDF${_totalPages > 0 ? ' — P.$_currentPage/$_totalPages' : ''}'),
        actions: [
          if (_rects.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last region',
              onPressed: () => setState(() => _rects.removeLast()),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear page',
            onPressed: _rects.isEmpty ? null : () => setState(() => _rects.clear()),
          ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.REDACT_PDF] != c.httpStates[HttpStates.REDACT_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.REDACT_PDF] != c.httpStates[HttpStates.REDACT_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.REDACT_PDF];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Redacted successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path},
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.REDACT_PDF]?.loading == true;
          return Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Drag to draw black rectangles over content to redact.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              Expanded(child: _loadingPage
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCanvas()),
              if (_totalPages > 1) _buildPageNav(theme),
              _buildSaveBar(theme, loading),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.REDACT_PDF]),
          ]);
        },
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final canvasW = constraints.maxWidth;
      final canvasH = constraints.maxHeight;

      final pageAspect = _pageWidthPt / _pageHeightPt;
      final canvasAspect = canvasW / canvasH;
      double imgW, imgH;
      if (pageAspect > canvasAspect) {
        imgW = canvasW;
        imgH = canvasW / pageAspect;
      } else {
        imgH = canvasH;
        imgW = canvasH * pageAspect;
      }

      // Capture canvas size for coordinate conversion in _onSave
      _lastImgW = imgW;
      _lastImgH = imgH;

      return Center(
        child: SizedBox(
          width: imgW, height: imgH,
          child: Stack(children: [
            if (_pageImage != null)
              Positioned.fill(child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill)),
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (d) => setState(() { _dragStart = d.localPosition; _dragEnd = d.localPosition; }),
                onPanUpdate: (d) => setState(() => _dragEnd = d.localPosition),
                onPanEnd: (_) {
                  if (_dragStart != null && _dragEnd != null) {
                    final r = _normalizeRect(_dragStart!, _dragEnd!);
                    if (r.width > 4 && r.height > 4) {
                      setState(() => _rects.add(_RedactRect(r)));
                    }
                  }
                  setState(() { _dragStart = null; _dragEnd = null; });
                },
                child: CustomPaint(
                  painter: _RedactPainter(_rects, _dragStart, _dragEnd),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Rect _normalizeRect(Offset a, Offset b) =>
      Rect.fromLTRB(a.dx < b.dx ? a.dx : b.dx, a.dy < b.dy ? a.dy : b.dy,
          a.dx > b.dx ? a.dx : b.dx, a.dy > b.dy ? a.dy : b.dy);

  Widget _buildPageNav(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
        ),
        Text('$_currentPage / $_totalPages'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages ? () => _loadPage(_currentPage + 1) : null,
        ),
      ]),
    );
  }

  Widget _buildSaveBar(ThemeData theme, bool loading) {
    final hasRects = _pageRects.values.any((l) => l.isNotEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: FilledButton.icon(
        onPressed: hasRects && !loading ? _onSave : null,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.hide_source),
        label: Text(loading ? 'Redacting…' : 'Apply Redactions'),
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
      ),
    );
  }

  Future<void> _onSave() async {
    final regions = <RedactRegion>[];
    _pageRects.forEach((page, rects) {
      for (final r in rects) {
        // Convert from canvas coords to PDF points (top-left origin, same as client)
        // Backend handles Y-inversion (PDFBox bottom-left origin)
        final scaleX = _pageWidthPt / _lastImgW;
        final scaleY = _pageHeightPt / _lastImgH;
        regions.add(RedactRegion(
          page: page - 1,
          x: r.rect.left * scaleX,
          y: r.rect.top * scaleY,
          width: r.rect.width * scaleX,
          height: r.rect.height * scaleY,
        ));
      }
    });

    BlocProvider.of<PdfBloc>(context).add(RedactPdfEvent(
      redactPdf: RedactPdf(
        regions: regions,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }
}

class _RedactRect {
  final Rect rect;
  _RedactRect(this.rect);
}

class _RedactPainter extends CustomPainter {
  final List<_RedactRect> confirmed;
  final Offset? dragStart;
  final Offset? dragEnd;

  _RedactPainter(this.confirmed, this.dragStart, this.dragEnd);

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    // Draw confirmed regions as solid black
    for (final r in confirmed) {
      canvas.drawRect(r.rect, fillPaint);
    }
    // Draw in-progress drag as semi-transparent red
    if (dragStart != null && dragEnd != null) {
      final r = Rect.fromPoints(dragStart!, dragEnd!);
      canvas.drawRect(r, Paint()..color = Colors.red.withValues(alpha: 0.4)..style = PaintingStyle.fill);
      canvas.drawRect(r, Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_RedactPainter old) => true;
}
