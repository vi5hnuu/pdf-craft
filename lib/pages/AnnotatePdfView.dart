import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_craft/models/request/stamp-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/apis/PdfService.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

// ── Tool enum ─────────────────────────────────────────────────────────────────

enum _Tool { pen, highlighter, eraser, text, rect, ellipse, line, arrow, sticky, zoom }

// ── Draw object sealed hierarchy ──────────────────────────────────────────────

sealed class _DrawObj {}

class _StrokeObj extends _DrawObj {
  final List<Offset> pts;
  final Color color;
  final double width;
  final bool isEraser;
  _StrokeObj({required this.pts, required this.color, required this.width, this.isEraser = false});
}

class _TextObj extends _DrawObj {
  final Offset pos;
  final String text;
  final double fontSize;
  final Color color;
  final bool bold;
  _TextObj({required this.pos, required this.text, this.fontSize = 16, required this.color, this.bold = false});
}

enum _ShapeType { rect, ellipse }

class _ShapeObj extends _DrawObj {
  final _ShapeType type;
  final Offset start;
  final Offset end;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  _ShapeObj({required this.type, required this.start, required this.end, required this.strokeColor, this.fillColor, this.strokeWidth = 2});
}

class _LineObj extends _DrawObj {
  final Offset from;
  final Offset to;
  final Color color;
  final double width;
  final bool arrow;
  _LineObj({required this.from, required this.to, required this.color, this.width = 2, this.arrow = false});
}

class _StickyObj extends _DrawObj {
  final Offset pos;
  final String text;
  final Color bgColor;
  _StickyObj({required this.pos, required this.text, required this.bgColor});
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

  // Draw objects per page
  final Map<int, List<_DrawObj>> _pageObjects = {};
  List<_DrawObj> get _objects => _pageObjects[_currentPage] ??= [];

  // Undo / redo stacks (page-local, cleared on navigate)
  final List<List<_DrawObj>> _undoStack = [];
  final List<List<_DrawObj>> _redoStack = [];

  // Active tool
  _Tool _tool = _Tool.pen;
  Color _strokeColor = Colors.red;
  Color? _fillColor;
  bool _useFill = false;
  double _strokeWidth = 3.0;
  double _fontSize = 16.0;
  bool _boldText = false;

  // Shape preview
  Offset? _shapeStart;
  Offset? _shapePreviewEnd;

  // Active stroke (pen / highlighter / eraser)
  _StrokeObj? _activeStroke;

  // Zoom
  bool _zoomMode = false;

  // Capture key for RepaintBoundary
  final GlobalKey _annotationKey = GlobalKey();

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
    // Clear undo/redo on page change — they are page-local
    _undoStack.clear();
    _redoStack.clear();
    setState(() => _loadingPage = true);
    try {
      final page = await _doc!.getPage(pageNo);
      _pageWidthPt = page.width;
      _pageHeightPt = page.height;
      final img = await page.render(width: page.width * 2, height: page.height * 2, format: PdfPageImageFormat.jpeg);
      await page.close();
      if (!mounted) return;
      setState(() { _pageImage = img; _currentPage = pageNo; _loadingPage = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  void _pushUndo() {
    _undoStack.add(List.from(_objects));
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_objects));
    setState(() => _pageObjects[_currentPage] = _undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.from(_objects));
    setState(() => _pageObjects[_currentPage] = _redoStack.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Annotate${_totalPages > 0 ? ' — P.$_currentPage/$_totalPages' : ''}'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), tooltip: 'Undo', onPressed: _undoStack.isEmpty ? null : _undo),
          IconButton(icon: const Icon(Icons.redo), tooltip: 'Redo', onPressed: _redoStack.isEmpty ? null : _redo),
          IconButton(
            icon: Icon(_zoomMode ? Icons.zoom_out : Icons.zoom_in, color: _zoomMode ? theme.colorScheme.primary : null),
            tooltip: 'Zoom',
            onPressed: () => setState(() => _zoomMode = !_zoomMode),
          ),
        ],
      ),
      // Save is handled directly in _onSave via PdfService; BlocConsumer here only
      // provides the loading overlay for any other STAMP_PDF operations on this screen.
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listenWhen: (_, __) => false,
        listener: (context, state) {},
        builder: (context, state) {
          return Stack(children: [
            Column(children: [
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvas(theme),
              ),
              if (_totalPages > 1) _buildPageNav(theme),
              _buildToolbar(theme),
              _buildOptionsPanel(theme),
              _buildSaveBar(theme, state),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.STAMP_PDF]),
          ]);
        },
      ),
    );
  }

  // ── Canvas ────────────────────────────────────────────────────────────────

  Widget _buildCanvas(ThemeData theme) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final canvasW = constraints.maxWidth;
      final canvasH = constraints.maxHeight;
      final pageAspect = _pageWidthPt / _pageHeightPt;
      final canvasAspect = canvasW / canvasH;
      double imgW, imgH;
      if (pageAspect > canvasAspect) {
        imgW = canvasW; imgH = canvasW / pageAspect;
      } else {
        imgH = canvasH; imgW = canvasH * pageAspect;
      }

      Widget canvas = SizedBox(
        width: imgW, height: imgH,
        child: Stack(children: [
          if (_pageImage != null)
            Positioned.fill(child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill)),
          Positioned.fill(
            child: RepaintBoundary(
              key: _annotationKey,
              child: _zoomMode
                  ? InteractiveViewer(
                      child: CustomPaint(
                        painter: _AnnotationPainter(_objects, _shapeStart, _shapePreviewEnd, _strokeColor),
                        child: Container(color: Colors.transparent),
                      ),
                    )
                  : GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      onTapUp: _onTapUp,
                      child: CustomPaint(
                        painter: _AnnotationPainter(_objects, _shapeStart, _shapePreviewEnd, _strokeColor),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
            ),
          ),
        ]),
      );

      return Center(child: canvas);
    });
  }

  void _onPanStart(DragStartDetails d) {
    final pos = d.localPosition;
    if (_tool == _Tool.pen || _tool == _Tool.highlighter || _tool == _Tool.eraser) {
      _pushUndo();
      final stroke = _StrokeObj(
        pts: [pos],
        color: _tool == _Tool.highlighter
            ? _strokeColor.withValues(alpha: 0.4)
            : (_tool == _Tool.eraser ? Colors.white : _strokeColor),
        width: _tool == _Tool.highlighter ? 20 : (_tool == _Tool.eraser ? 24 : _strokeWidth),
        isEraser: _tool == _Tool.eraser,
      );
      setState(() { _objects.add(stroke); _activeStroke = stroke; });
    } else if (_isShapeTool(_tool)) {
      setState(() { _shapeStart = pos; _shapePreviewEnd = pos; });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_tool == _Tool.pen || _tool == _Tool.highlighter || _tool == _Tool.eraser) {
      if (_activeStroke == null) return;
      setState(() => _activeStroke!.pts.add(d.localPosition));
    } else if (_isShapeTool(_tool)) {
      setState(() => _shapePreviewEnd = d.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_tool == _Tool.pen || _tool == _Tool.highlighter || _tool == _Tool.eraser) {
      setState(() => _activeStroke = null);
    } else if (_isShapeTool(_tool) && _shapeStart != null && _shapePreviewEnd != null) {
      _pushUndo();
      final start = _shapeStart!;
      final end = _shapePreviewEnd!;
      _DrawObj obj;
      if (_tool == _Tool.rect) {
        obj = _ShapeObj(type: _ShapeType.rect, start: start, end: end, strokeColor: _strokeColor, fillColor: _useFill ? _fillColor : null, strokeWidth: _strokeWidth);
      } else if (_tool == _Tool.ellipse) {
        obj = _ShapeObj(type: _ShapeType.ellipse, start: start, end: end, strokeColor: _strokeColor, fillColor: _useFill ? _fillColor : null, strokeWidth: _strokeWidth);
      } else if (_tool == _Tool.line) {
        obj = _LineObj(from: start, to: end, color: _strokeColor, width: _strokeWidth, arrow: false);
      } else {
        obj = _LineObj(from: start, to: end, color: _strokeColor, width: _strokeWidth, arrow: true);
      }
      setState(() { _objects.add(obj); _shapeStart = null; _shapePreviewEnd = null; });
    }
  }

  void _onTapUp(TapUpDetails d) {
    if (_tool == _Tool.text) _showTextDialog(d.localPosition);
    if (_tool == _Tool.sticky) _showStickySheet(d.localPosition);
  }

  bool _isShapeTool(_Tool t) => t == _Tool.rect || t == _Tool.ellipse || t == _Tool.line || t == _Tool.arrow;

  // ── Toolbar (horizontal scroll) ───────────────────────────────────────────

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          _toolBtn(_Tool.pen, Icons.edit_outlined, 'Pen', theme),
          _toolBtn(_Tool.highlighter, Icons.highlight_outlined, 'Highlight', theme),
          _toolBtn(_Tool.eraser, Icons.auto_fix_normal, 'Eraser', theme),
          _vDivider(),
          _toolBtn(_Tool.text, Icons.text_fields, 'Text', theme),
          _toolBtn(_Tool.sticky, Icons.sticky_note_2_outlined, 'Sticky', theme),
          _vDivider(),
          _toolBtn(_Tool.rect, Icons.crop_square_outlined, 'Rectangle', theme),
          _toolBtn(_Tool.ellipse, Icons.circle_outlined, 'Ellipse', theme),
          _toolBtn(_Tool.line, Icons.remove, 'Line', theme),
          _toolBtn(_Tool.arrow, Icons.arrow_forward_outlined, 'Arrow', theme),
        ]),
      ),
    );
  }

  Widget _toolBtn(_Tool t, IconData icon, String tip, ThemeData theme) {
    final active = _tool == t;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: IconButton(
        icon: Icon(icon, color: active ? theme.colorScheme.primary : null),
        tooltip: tip,
        style: active ? IconButton.styleFrom(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15)) : null,
        onPressed: () => setState(() { _tool = t; _zoomMode = false; }),
      ),
    );
  }

  Widget _vDivider() => const SizedBox(
    height: 32,
    child: VerticalDivider(width: 16, indent: 4, endIndent: 4),
  );

  // ── Context-sensitive options panel ──────────────────────────────────────

  Widget _buildOptionsPanel(ThemeData theme) {
    if (_tool == _Tool.eraser || _tool == _Tool.zoom) return const SizedBox.shrink();

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_tool == _Tool.text) _buildTextOptions(theme)
        else if (_tool == _Tool.sticky) _buildStickyHint(theme)
        else _buildStrokeOptions(theme),
      ]),
    );
  }

  Widget _buildStrokeOptions(ThemeData theme) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        // Quick color swatches
        ...{Colors.red, Colors.blue, Colors.green, Colors.black, Colors.orange, Colors.purple}
            .map((c) => GestureDetector(
              onTap: () => setState(() => _strokeColor = c),
              child: Container(
                width: 26, height: 26,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(color: _strokeColor == c ? Colors.white : Colors.transparent, width: 2),
                  boxShadow: _strokeColor == c ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)] : [],
                ),
              ),
            )),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.color_lens_outlined, size: 22),
          tooltip: 'More colors',
          onPressed: _showColorPicker,
        ),
        const Spacer(),
        if (_isShapeTool(_tool)) ...[
          const Text('Fill', style: TextStyle(fontSize: 12)),
          Switch(value: _useFill, onChanged: (v) => setState(() => _useFill = v)),
          if (_useFill)
            GestureDetector(
              onTap: _showFillPicker,
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: _fillColor ?? Colors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
            ),
        ],
      ]),
      Row(children: [
        const Text('Size:', style: TextStyle(fontSize: 12)),
        Expanded(
          child: Slider(
            value: _strokeWidth.clamp(1, 20),
            min: 1, max: 20,
            onChanged: (v) => setState(() => _strokeWidth = v),
          ),
        ),
        Text('${_strokeWidth.round()}px', style: const TextStyle(fontSize: 12)),
      ]),
    ]);
  }

  Widget _buildTextOptions(ThemeData theme) {
    return Row(children: [
      ...{Colors.black, Colors.red, Colors.blue, Colors.green}
          .map((c) => GestureDetector(
            onTap: () => setState(() => _strokeColor = c),
            child: Container(
              width: 24, height: 24,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: Border.all(color: _strokeColor == c ? Colors.white : Colors.transparent, width: 2),
              ),
            ),
          )),
      IconButton(icon: const Icon(Icons.color_lens_outlined, size: 20), onPressed: _showColorPicker),
      const SizedBox(width: 8),
      const Text('Size:', style: TextStyle(fontSize: 12)),
      Expanded(
        child: Slider(
          value: _fontSize.clamp(8, 72),
          min: 8, max: 72,
          onChanged: (v) => setState(() => _fontSize = v),
        ),
      ),
      IconButton(
        icon: Icon(Icons.format_bold, color: _boldText ? theme.colorScheme.primary : null),
        tooltip: 'Bold',
        onPressed: () => setState(() => _boldText = !_boldText),
      ),
    ]);
  }

  Widget _buildStickyHint(ThemeData theme) {
    return Row(children: [
      const Icon(Icons.info_outline, size: 16, color: Colors.grey),
      const SizedBox(width: 8),
      Text('Tap on the page to place a sticky note', style: theme.textTheme.bodySmall),
    ]);
  }

  // ── Page nav ──────────────────────────────────────────────────────────────

  Widget _buildPageNav(ThemeData theme) {
    return Container(
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

  // ── Save bar ──────────────────────────────────────────────────────────────

  Widget _buildSaveBar(ThemeData theme, PdfState state) {
    final hasAnnotations = _pageObjects.values.any((l) => l.isNotEmpty);
    final loading = state.httpStates[HttpStates.STAMP_PDF]?.loading == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: FilledButton.icon(
        onPressed: hasAnnotations && !_saving && !loading ? _onSave : null,
        icon: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_alt),
        label: Text(_saving ? 'Saving…' : 'Save Annotations'),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showTextDialog(Offset pos) {
    final textC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(
          controller: textC,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter text…', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (textC.text.isNotEmpty) {
                _pushUndo();
                setState(() => _objects.add(_TextObj(
                  pos: pos, text: textC.text,
                  fontSize: _fontSize, color: _strokeColor, bold: _boldText,
                )));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showStickySheet(Offset pos) {
    final textC = TextEditingController();
    Color stickyColor = Colors.yellow;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Sticky Note', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: textC,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Note text…', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final c in [Colors.yellow, Colors.orange.shade200, Colors.green.shade200, Colors.blue.shade200, Colors.pink.shade200])
                GestureDetector(
                  onTap: () => setS(() => stickyColor = c),
                  child: Container(
                    width: 30, height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: c, shape: BoxShape.circle,
                      border: Border.all(
                        color: stickyColor == c ? Colors.black54 : Colors.transparent, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (textC.text.isNotEmpty) {
                    _pushUndo();
                    setState(() => _objects.add(_StickyObj(pos: pos, text: textC.text, bgColor: stickyColor)));
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Place Sticky'),
              ),
            ),
          ]),
        ),
      )),
    );
  }

  void _showColorPicker() {
    Color picked = _strokeColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick color'),
        content: ColorPicker(
          pickerColor: picked,
          onColorChanged: (c) => picked = c,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { setState(() => _strokeColor = picked); Navigator.pop(ctx); },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _showFillPicker() {
    Color picked = _fillColor ?? Colors.yellow;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fill color'),
        content: ColorPicker(
          pickerColor: picked,
          onColorChanged: (c) => picked = c,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { setState(() => _fillColor = picked); Navigator.pop(ctx); },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Saves all annotated pages sequentially.
  /// Navigates to each annotated page, captures the RepaintBoundary, and stamps
  /// it via direct service call so the result file can be chained into the next stamp.
  Future<void> _onSave() async {
    final annotatedPages = _pageObjects.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList()..sort();
    if (annotatedPages.isEmpty) return;

    setState(() => _saving = true);
    try {
      final baseName = 'annotated_${widget.file.path.split('/').last.replaceAll('.pdf', '')}';
      File inputFile = widget.file;

      for (final pageNo in annotatedPages) {
        if (_currentPage != pageNo) {
          await _loadPage(pageNo);
          // Wait for the next frame so the painter fully renders before capture
          await WidgetsBinding.instance.endOfFrame;
        }

        final boundary = _annotationKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;

        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final tmpDir = await getTemporaryDirectory();
        final stampFile = File('${tmpDir.path}/ann_p${pageNo}_${DateTime.now().millisecondsSinceEpoch}.png');
        await stampFile.writeAsBytes(byteData.buffer.asUint8List());

        // Direct service call so result file can be used as input for the next page
        final resp = await PdfService().stampPdf(
          stampPdf: StampPdf(
            outFileName: baseName,
            opacity: 1.0,
            fromPage: pageNo - 1,
            toPage: pageNo - 1,
            file: await MultipartFile.fromFile(inputFile.path),
            stamp: await MultipartFile.fromFile(
                stampFile.path, contentType: DioMediaType.parse('image/png')),
          ),
        );

        if (resp.data != null) {
          final outDir = Directory(Constants.processedDirPath);
          if (!outDir.existsSync()) await outDir.create(recursive: true);
          final outFile = File('${outDir.path}/$baseName.pdf');
          await outFile.writeAsBytes(resp.data!);
          inputFile = outFile;
        }
      }

      if (!mounted) return;
      AdsSingleton().dispatch(ShowInterstitialAd());
      NotificationService.showSnackbar(text: 'Annotations saved', color: Colors.green);
      GoRouter.of(context).pushNamed(
        AppRoutes.pdfFilePreviewRoute.name,
        pathParameters: {'pdfFilePath': inputFile.path},
      );
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Save failed: $e', color: Colors.red);
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
  final List<_DrawObj> objects;
  final Offset? previewStart;
  final Offset? previewEnd;
  final Color previewColor;

  _AnnotationPainter(this.objects, this.previewStart, this.previewEnd, this.previewColor);

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer required for eraser BlendMode.clear to work correctly
    canvas.saveLayer(Offset.zero & size, Paint());

    for (final obj in objects) {
      _paintObj(canvas, obj);
    }

    // In-progress shape preview (dashed/semi-transparent)
    if (previewStart != null && previewEnd != null) {
      final paint = Paint()
        ..color = previewColor.withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromPoints(previewStart!, previewEnd!), paint);
    }

    canvas.restore();
  }

  void _paintObj(Canvas canvas, _DrawObj obj) {
    switch (obj) {
      case _StrokeObj s:
        final paint = Paint()
          ..color = s.color
          ..strokeWidth = s.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..blendMode = s.isEraser ? BlendMode.clear : BlendMode.srcOver;
        if (s.pts.length == 1) {
          canvas.drawCircle(s.pts.first, s.width / 2, paint..style = PaintingStyle.fill);
        } else {
          final path = Path()..moveTo(s.pts.first.dx, s.pts.first.dy);
          for (int i = 1; i < s.pts.length; i++) {
            path.lineTo(s.pts[i].dx, s.pts[i].dy);
          }
          canvas.drawPath(path, paint);
        }

      case _TextObj t:
        final tp = TextPainter(
          text: TextSpan(
            text: t.text,
            style: TextStyle(
              color: t.color,
              fontSize: t.fontSize,
              fontWeight: t.bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 300);
        tp.paint(canvas, t.pos);

      case _ShapeObj s:
        final rect = Rect.fromPoints(s.start, s.end);
        if (s.fillColor != null) {
          final fillPaint = Paint()..color = s.fillColor!..style = PaintingStyle.fill;
          if (s.type == _ShapeType.rect) canvas.drawRect(rect, fillPaint);
          else canvas.drawOval(rect, fillPaint);
        }
        final strokePaint = Paint()
          ..color = s.strokeColor
          ..strokeWidth = s.strokeWidth
          ..style = PaintingStyle.stroke;
        if (s.type == _ShapeType.rect) canvas.drawRect(rect, strokePaint);
        else canvas.drawOval(rect, strokePaint);

      case _LineObj l:
        final paint = Paint()
          ..color = l.color
          ..strokeWidth = l.width
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(l.from, l.to, paint);
        if (l.arrow) _drawArrowHead(canvas, l.from, l.to, l.color, l.width);

      case _StickyObj s:
        final rRect = RRect.fromRectAndRadius(Rect.fromLTWH(s.pos.dx, s.pos.dy, 120, 80), const Radius.circular(6));
        canvas.drawRRect(rRect, Paint()..color = s.bgColor..style = PaintingStyle.fill);
        canvas.drawRRect(rRect, Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1);
        final tp = TextPainter(
          text: TextSpan(text: s.text, style: const TextStyle(color: Colors.black87, fontSize: 12)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 108);
        tp.paint(canvas, Offset(s.pos.dx + 6, s.pos.dy + 6));
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Color color, double width) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const arrowSize = 14.0;
    final path = Path();
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * math.cos(angle - 0.45),
      to.dy - arrowSize * math.sin(angle - 0.45),
    );
    path.lineTo(
      to.dx - arrowSize * math.cos(angle + 0.45),
      to.dy - arrowSize * math.sin(angle + 0.45),
    );
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}
