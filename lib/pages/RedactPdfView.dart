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

/// Draw black redaction boxes over content, then **reposition, resize or delete
/// each box** before applying. Previously a drawn box was final; now every box
/// is a movable/resizable object with handles, for a smooth editor-like flow.
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

  final Map<int, List<_RedactRegion>> _pageRects = {};
  List<_RedactRegion> get _rects => _pageRects[_currentPage] ??= [];

  String? _selectedId;
  CancelToken? _cancelToken;

  // In-progress draw rectangle.
  Offset? _dragStart;
  Offset? _dragEnd;

  // Rendered page size, for canvas→PDF-point conversion on save.
  double _lastImgW = 0;
  double _lastImgH = 0;

  static const double _minSize = 12;

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
      setState(() {
        _pageImage = img;
        _currentPage = pageNo;
        _selectedId = null;
        _loadingPage = false;
      });
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
              onPressed: () => setState(() {
                _rects.removeLast();
                _selectedId = null;
              }),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear page',
            onPressed: _rects.isEmpty
                ? null
                : () => setState(() {
                      _rects.clear();
                      _selectedId = null;
                    }),
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
                  'Drag on an empty area to draw a box. Tap a box to move, resize (corner) or delete it.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              Expanded(child: _loadingPage ? const Center(child: CircularProgressIndicator()) : _buildCanvas()),
              if (_totalPages > 1) _buildPageNav(theme),
              _buildSaveBar(theme, loading),
            ]),
            LoadingOverlay(
              httpState: state.httpStates[HttpStates.REDACT_PDF],
              label: 'Redacting your PDF',
              onCancel: () => _cancelToken?.cancel('cancelled-by-user'),
            ),
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
      _lastImgW = imgW;
      _lastImgH = imgH;

      return Center(
        child: SizedBox(
          width: imgW,
          height: imgH,
          child: Stack(children: [
            if (_pageImage != null)
              Positioned.fill(child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill)),

            // Draw layer for NEW boxes — sits below existing boxes so panning on a
            // box moves it, while panning on empty space draws a new one.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _selectedId = null),
                onPanStart: (d) => setState(() {
                  _selectedId = null;
                  _dragStart = d.localPosition;
                  _dragEnd = d.localPosition;
                }),
                onPanUpdate: (d) => setState(() => _dragEnd = _clampToCanvas(d.localPosition, imgW, imgH)),
                onPanEnd: (_) {
                  if (_dragStart != null && _dragEnd != null) {
                    final r = _normalizeRect(_dragStart!, _dragEnd!);
                    if (r.width > _minSize && r.height > _minSize) {
                      final region = _RedactRegion(r);
                      setState(() {
                        _rects.add(region);
                        _selectedId = region.id;
                      });
                    }
                  }
                  setState(() {
                    _dragStart = null;
                    _dragEnd = null;
                  });
                },
                child: CustomPaint(painter: _DragPreviewPainter(_dragStart, _dragEnd)),
              ),
            ),

            // Existing redaction boxes (on top, each interactive).
            ..._rects.map((region) => _RedactBox(
                  key: ValueKey(region.id),
                  region: region,
                  selected: _selectedId == region.id,
                  canvasW: imgW,
                  canvasH: imgH,
                  minSize: _minSize,
                  onSelect: () => setState(() => _selectedId = region.id),
                  onChanged: () => setState(() {}),
                  onDelete: () => setState(() {
                    _rects.remove(region);
                    _selectedId = null;
                  }),
                )),
          ]),
        ),
      );
    });
  }

  Offset _clampToCanvas(Offset o, double w, double h) =>
      Offset(o.dx.clamp(0.0, w), o.dy.clamp(0.0, h));

  Rect _normalizeRect(Offset a, Offset b) => Rect.fromLTRB(
        a.dx < b.dx ? a.dx : b.dx,
        a.dy < b.dy ? a.dy : b.dy,
        a.dx > b.dx ? a.dx : b.dx,
        a.dy > b.dy ? a.dy : b.dy,
      );

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
    final scaleX = _pageWidthPt / _lastImgW;
    final scaleY = _pageHeightPt / _lastImgH;
    _pageRects.forEach((page, rects) {
      for (final r in rects) {
        regions.add(RedactRegion(
          page: page - 1,
          x: r.rect.left * scaleX,
          y: r.rect.top * scaleY,
          width: r.rect.width * scaleX,
          height: r.rect.height * scaleY,
        ));
      }
    });

    _cancelToken = CancelToken();
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    BlocProvider.of<PdfBloc>(context).add(RedactPdfEvent(
      redactPdf: RedactPdf(regions: regions, file: file),
      cancelToken: _cancelToken,
    ));
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }
}

/// A single redaction region. [rect] is mutable so it can be moved/resized.
class _RedactRegion {
  Rect rect;
  final String id;
  _RedactRegion(this.rect) : id = UniqueKey().toString();
}

/// Interactive black box: drag body to move, drag the corner handle to resize,
/// tap ✕ to delete. Position is kept within the page bounds.
class _RedactBox extends StatelessWidget {
  final _RedactRegion region;
  final bool selected;
  final double canvasW, canvasH, minSize;
  final VoidCallback onSelect;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _RedactBox({
    super.key,
    required this.region,
    required this.selected,
    required this.canvasW,
    required this.canvasH,
    required this.minSize,
    required this.onSelect,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = region.rect;
    return Positioned(
      left: r.left,
      top: r.top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        onPanStart: (_) => onSelect(),
        onPanUpdate: (d) {
          // Move, clamped so the box stays fully on the page.
          final nl = (r.left + d.delta.dx).clamp(0.0, canvasW - r.width);
          final nt = (r.top + d.delta.dy).clamp(0.0, canvasH - r.height);
          region.rect = Rect.fromLTWH(nl, nt, r.width, r.height);
          onChanged();
        },
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: r.width,
            height: r.height,
            decoration: BoxDecoration(
              color: Colors.black,
              border: selected ? Border.all(color: Colors.blueAccent, width: 2) : null,
            ),
          ),
          if (selected) ...[
            // Delete handle.
            Positioned(
              top: -12,
              right: -12,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
            // Resize handle (bottom-right).
            Positioned(
              right: -10,
              bottom: -10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  final nw = (r.width + d.delta.dx).clamp(minSize, canvasW - r.left);
                  final nh = (r.height + d.delta.dy).clamp(minSize, canvasH - r.top);
                  region.rect = Rect.fromLTWH(r.left, r.top, nw, nh);
                  onChanged();
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.open_in_full, color: Colors.white, size: 11),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Paints only the in-progress drag rectangle (confirmed boxes are widgets).
class _DragPreviewPainter extends CustomPainter {
  final Offset? dragStart;
  final Offset? dragEnd;
  _DragPreviewPainter(this.dragStart, this.dragEnd);

  @override
  void paint(Canvas canvas, Size size) {
    if (dragStart == null || dragEnd == null) return;
    final r = Rect.fromPoints(dragStart!, dragEnd!);
    canvas.drawRect(r, Paint()..color = Colors.red.withValues(alpha: 0.35)..style = PaintingStyle.fill);
    canvas.drawRect(r, Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_DragPreviewPainter old) => old.dragStart != dragStart || old.dragEnd != dragEnd;
}
