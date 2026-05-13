import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_craft/models/request/stamp-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

// ── Annotation model ──────────────────────────────────────────────────────────

enum _AnnotationTool { pen, highlighter, eraser }

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;
  _Stroke({required this.points, required this.color, required this.width, this.isEraser = false});
}

// ── Main view ─────────────────────────────────────────────────────────────────

class AnnotatePdfView extends StatefulWidget {
  final File file;
  const AnnotatePdfView({super.key, required this.file});

  @override
  State<AnnotatePdfView> createState() => _AnnotatePdfViewState();
}

class _AnnotatePdfViewState extends State<AnnotatePdfView> {
  // Page state
  PdfDocument? _doc;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfPageImage? _pageImage;
  double _pageWidthPt = 595;
  double _pageHeightPt = 842;
  bool _loadingPage = true;

  // Annotation state (per-page strokes)
  final Map<int, List<_Stroke>> _pageStrokes = {};
  List<_Stroke> get _strokes => _pageStrokes[_currentPage] ??= [];
  _Stroke? _activeStroke;

  // Tool state
  _AnnotationTool _tool = _AnnotationTool.pen;
  Color _color = Colors.red;
  double _penWidth = 3.0;
  double _highlightWidth = 18.0;

  // Capture key for RepaintBoundary (annotation layer only)
  final GlobalKey _annotationKey = GlobalKey();

  // Saving state
  bool _saving = false;

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
        title: Text('Annotate PDF${_totalPages > 0 ? ' — Page $_currentPage / $_totalPages' : ''}'),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _strokes.isEmpty ? null : () => setState(() => _strokes.removeLast()),
          ),
          // Clear page
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear page',
            onPressed: _strokes.isEmpty ? null : () => setState(() => _strokes.clear()),
          ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.STAMP_PDF];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(
                text: 'Annotations applied', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {
                  'pdfFilePath': (s!.extras!['savedFile'] as File).path
                },
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(
                text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(
                text: 'Saving annotations…', color: Colors.lightBlue);
          }
        },
        builder: (context, state) {
          return Stack(children: [
            Column(children: [
              // ── Toolbar ──────────────────────────────────────────────
              _buildToolbar(theme),
              const Divider(height: 1),

              // ── Drawing canvas ────────────────────────────────────────
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvas(theme),
              ),

              // ── Page navigation ───────────────────────────────────────
              if (_totalPages > 1) _buildPageNav(theme),

              // ── Save bar ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton.icon(
                  onPressed: _saving || !_hasAnyAnnotations ? null : _onSave,
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_alt),
                  label: Text(_saving ? 'Saving…' : 'Save Annotations'),
                ),
              ),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.STAMP_PDF]),
          ]);
        },
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        // Tools
        _toolBtn(_AnnotationTool.pen, Icons.edit, 'Pen', primary),
        _toolBtn(_AnnotationTool.highlighter, Icons.highlight, 'Highlight', primary),
        _toolBtn(_AnnotationTool.eraser, Icons.auto_fix_normal, 'Eraser', primary),
        const SizedBox(width: 8),
        const VerticalDivider(width: 1, indent: 4, endIndent: 4),
        const SizedBox(width: 8),

        // Color swatches (only for pen/highlighter)
        if (_tool != _AnnotationTool.eraser) ...[
          ...{Colors.red, Colors.blue, Colors.green, Colors.black, Colors.orange}
              .map((c) => GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 26, height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: _color == c
                            ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)]
                            : [],
                      ),
                    ),
                  )),
          const SizedBox(width: 8),
        ],

        // Stroke width
        if (_tool == _AnnotationTool.pen) ...[
          const Text('Size:', style: TextStyle(fontSize: 12)),
          SizedBox(
            width: 90,
            child: Slider(
              value: _penWidth,
              min: 1, max: 10,
              onChanged: (v) => setState(() => _penWidth = v),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _toolBtn(_AnnotationTool t, IconData icon, String tip, Color primary) {
    final active = _tool == t;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: Icon(icon, color: active ? primary : null),
        tooltip: tip,
        style: active
            ? IconButton.styleFrom(
                backgroundColor: primary.withValues(alpha: 0.15))
            : null,
        onPressed: () => setState(() => _tool = t),
      ),
    );
  }

  Widget _buildCanvas(ThemeData theme) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final canvasW = constraints.maxWidth;
      final canvasH = constraints.maxHeight;

      // Fit page inside canvas maintaining aspect ratio
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

      return Center(
        child: SizedBox(
          width: imgW, height: imgH,
          child: Stack(children: [
            // Page background
            if (_pageImage != null)
              Positioned.fill(
                child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill),
              )
            else
              Positioned.fill(
                child: Container(color: Colors.white),
              ),

            // Annotation capture boundary
            Positioned.fill(
              child: RepaintBoundary(
                key: _annotationKey,
                child: GestureDetector(
                  onPanStart: (d) {
                    final s = _Stroke(
                      points: [d.localPosition],
                      color: _tool == _AnnotationTool.highlighter
                          ? _color.withValues(alpha: 0.35)
                          : (_tool == _AnnotationTool.eraser
                              ? Colors.white
                              : _color),
                      width: _tool == _AnnotationTool.highlighter
                          ? _highlightWidth
                          : (_tool == _AnnotationTool.eraser ? 20 : _penWidth),
                      isEraser: _tool == _AnnotationTool.eraser,
                    );
                    setState(() {
                      _strokes.add(s);
                      _activeStroke = s;
                    });
                  },
                  onPanUpdate: (d) {
                    if (_activeStroke == null) return;
                    setState(() => _activeStroke!.points.add(d.localPosition));
                  },
                  onPanEnd: (_) => setState(() => _activeStroke = null),
                  child: CustomPaint(
                    painter: _AnnotationPainter(_strokes),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildPageNav(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => _loadPage(_currentPage - 1)
                : null,
          ),
          Text('$_currentPage / $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _loadPage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  bool get _hasAnyAnnotations =>
      _pageStrokes.values.any((strokes) => strokes.isNotEmpty);

  /// Captures the annotation layer as a transparent PNG and stamps it on the PDF.
  Future<void> _onSave() async {
    if (!_hasAnyAnnotations) return;
    setState(() => _saving = true);
    try {
      // Capture the current page's annotation layer
      final boundary = _annotationKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not capture annotations');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode annotation image');

      final tmpDir = await getTemporaryDirectory();
      final stampFile = File(
          '${tmpDir.path}/annotation_stamp_${DateTime.now().millisecondsSinceEpoch}.png');
      await stampFile.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;

      BlocProvider.of<PdfBloc>(context).add(StampPdfEvent(
        stampPdf: StampPdf(
          outFileName: 'annotated_${widget.file.path.split('/').last.replaceAll('.pdf', '')}',
          opacity: 1.0,
          // Apply annotation to current page only (0-indexed)
          fromPage: _currentPage - 1,
          toPage: _currentPage - 1,
          file: await MultipartFile.fromFile(widget.file.path),
          stamp: await MultipartFile.fromFile(stampFile.path,
              contentType: DioMediaType.parse('image/png')),
        ),
      ));
    } catch (e) {
      NotificationService.showSnackbar(
          text: 'Failed to save: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }
}

// ── Annotation painter ────────────────────────────────────────────────────────

class _AnnotationPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _AnnotationPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode =
            stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}
