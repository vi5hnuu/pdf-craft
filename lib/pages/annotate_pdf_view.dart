/// Annotate PDF — marking up a document and saving the marks as real PDF annotations.
///
/// Two things changed from the version this replaces, and they are related:
///
/// * **Marks live in page coordinates, not screen coordinates.** Everything is stored as a
///   fraction of the page (see [Annotation]). The old model kept raw canvas `Offset`s, which tied
///   each mark to the size of the canvas at the moment it was drawn — zooming slid the marks off
///   the page, the exported resolution was capped by the phone's screen, and the only thing that
///   could be sent to the server was a screenshot.
/// * **Marks are saved as annotations, not pixels.** One request carries the whole document's
///   geometry to `/annotate-pdf`, which writes `/Ink`, `/Highlight`, `/Square`, `/Circle`,
///   `/Line`, `/FreeText` and `/Text` objects. They stay sharp at any zoom, appear in a viewer's
///   comment list, and can be removed later. Saving used to stamp one rasterised PNG per annotated
///   page, re-uploading the growing PDF each time.
///
/// Images and signatures are the exception: a bitmap has no markup-annotation equivalent, so those
/// still go through the stamp endpoint, after the annotations are written.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/annotate_pdf.dart';
import 'package:pdf_craft/models/request/stamp_pdf.dart';
import 'package:pdf_craft/pages/annotate/annotation.dart';
import 'package:pdf_craft/pages/annotate/annotation_painter.dart';
import 'package:pdf_craft/pages/annotate/signature_sheet.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/file_store.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdfx/pdfx.dart';

enum _Tool { select, pen, highlighter, text, sticky, rect, ellipse, line, arrow }

class AnnotatePdfView extends StatefulWidget {
  final File file;
  const AnnotatePdfView({super.key, required this.file});

  @override
  State<AnnotatePdfView> createState() => _AnnotatePdfViewState();
}

class _AnnotatePdfViewState extends State<AnnotatePdfView>
    with ToolResultHandler, ToolViewMixin {
  // ── Document ──────────────────────────────────────────────────────────────
  PdfDocument? _doc;
  int _currentPage = 1;
  int _totalPages = 0;
  /// The rendered page, decoded. The painter draws it, so a highlighter has something to
  /// multiply against — see [AnnotationPainter.page].
  ui.Image? _pageDecoded;
  double _pageWidthPt = 595;
  double _pageHeightPt = 842;
  bool _loadingPage = true;

  // ── Marks ─────────────────────────────────────────────────────────────────
  /// Every mark in the document. Each one knows which page it is on, so one flat list is enough
  /// and — unlike the old per-page map with per-page undo stacks — history spans the document.
  final List<Annotation> _annotations = [];
  String? _selectedId;

  /// Document-wide history. Page-local stacks meant annotating page 1, moving to page 2 and
  /// coming back left page 1's work impossible to undo.
  final List<List<Annotation>> _undo = [];
  final List<List<Annotation>> _redo = [];

  // ── Tool + style ──────────────────────────────────────────────────────────
  _Tool _tool = _Tool.pen;
  Color _color = Colors.red;
  Color? _fill;
  final bool _useFill = false;
  double _opacity = 1.0;

  /// Fractions of the page, so a mark keeps its weight on any page size.
  double _strokeFrac = 0.004;
  double _fontFrac = 0.022;
  final bool _bold = false;

  // ── Canvas ────────────────────────────────────────────────────────────────
  /// The pixel size the page is currently rendered at. The bridge between page fractions and
  /// touch coordinates, and the reason a mark does not move when the canvas does.
  Size _canvasSize = Size.zero;
  final TransformationController _tc = TransformationController();
  Annotation? _preview;
  InkAnnotation? _activeStroke;
  Offset? _shapeStart;

  final Map<String, ui.Image> _images = {};
  bool _saving = false;

  /// See [AnnotatePdf.flatten]. Off by default, but surfaced right next to Export because the
  /// consequence is immediate and visible: leave it off and the marks will not show in this app's
  /// own preview, or in any other viewer that ignores annotations.
  bool _flatten = false;

  List<Annotation> get _pageMarks =>
      _annotations.where((a) => a.page == _currentPage - 1).toList();

  Annotation? get _selected {
    for (final a in _annotations) {
      if (a.id == _selectedId) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.annotatePdf, HttpStates.stampPdf]);
    _openDocument();
  }

  @override
  void dispose() {
    _tc.dispose();
    _doc?.close();
    // A ui.Image holds native memory that the garbage collector does not account for, so a
    // page render and every inserted image have to be handed back explicitly. A long document
    // paged through end to end would otherwise leak one full-page bitmap per page visited.
    _pageDecoded?.dispose();
    for (final image in _images.values) {
      image.dispose();
    }
    super.dispose();
  }

  // ── Document loading ──────────────────────────────────────────────────────

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
    final doc = _doc;
    if (doc == null) return;
    setState(() {
      _loadingPage = true;
      _selectedId = null;
    });
    try {
      final page = await doc.getPage(pageNo);
      _pageWidthPt = page.width;
      _pageHeightPt = page.height;
      final img = await page.render(
          width: page.width * 2, height: page.height * 2, format: PdfPageImageFormat.jpeg);
      await page.close();
      final decoded = img == null ? null : await decodeImageFromList(img.bytes);
      if (!mounted) {
        decoded?.dispose();
        return;
      }
      final previous = _pageDecoded;
      setState(() {
        _pageDecoded = decoded;
        _currentPage = pageNo;
        _loadingPage = false;
        // Each page starts unzoomed; a zoom level from the previous page means nothing here.
        _tc.value = Matrix4.identity();
      });
      // After the frame that paints the new page, so the outgoing image is not disposed while
      // it is still on screen.
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  // ── History ───────────────────────────────────────────────────────────────

  /// Snapshots every mark, deep-copied, so an in-place edit to a selected mark can be undone.
  void _pushUndo() {
    _undo.add([for (final a in _annotations) a.copy()]);
    _redo.clear();
  }

  void _restore(List<List<Annotation>> from, List<List<Annotation>> to) {
    if (from.isEmpty) return;
    to.add([for (final a in _annotations) a.copy()]);
    final snapshot = from.removeLast();
    setState(() {
      _annotations
        ..clear()
        ..addAll(snapshot);
      // The selection may have been one of the marks that just came back or went away.
      if (_selected == null) _selectedId = null;
    });
  }

  // ── Coordinates ───────────────────────────────────────────────────────────

  Offset _toFrac(Offset px) => Offset(
        (px.dx / math.max(_canvasSize.width, 1)).clamp(0.0, 1.0),
        (px.dy / math.max(_canvasSize.height, 1)).clamp(0.0, 1.0),
      );

  Rect _toPx(Rect frac) => Rect.fromLTWH(
        frac.left * _canvasSize.width,
        frac.top * _canvasSize.height,
        frac.width * _canvasSize.width,
        frac.height * _canvasSize.height,
      );

  // ── Drawing gestures ──────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    final p = _toFrac(d.localPosition);
    switch (_tool) {
      case _Tool.pen:
      case _Tool.highlighter:
        _pushUndo();
        final stroke = InkAnnotation(
          page: _currentPage - 1,
          color: _color,
          points: [p],
          strokeWidth: _tool == _Tool.highlighter ? _strokeFrac * 4 : _strokeFrac,
          highlighter: _tool == _Tool.highlighter,
          opacity: _opacity,
        );
        setState(() {
          _annotations.add(stroke);
          _activeStroke = stroke;
        });
      case _Tool.rect:
      case _Tool.ellipse:
      case _Tool.line:
      case _Tool.arrow:
        setState(() => _shapeStart = p);
      case _Tool.select:
      case _Tool.text:
      case _Tool.sticky:
        break;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final p = _toFrac(d.localPosition);
    final stroke = _activeStroke;
    if (stroke != null) {
      // Thinned as it is drawn. A pan reports a point per frame, so a two-second drag is well
      // over a hundred points — and a highlighter turns every segment into a QuadPoints quad,
      // so an unthinned scribble means a bloated file and a viewer that struggles to draw it.
      // At this spacing (about a point on A4) the difference is invisible.
      const minSpacing = 0.002;
      final last = stroke.points.last;
      if ((p - last).distance < minSpacing) return;
      setState(() => stroke.points.add(p));
      return;
    }
    final start = _shapeStart;
    if (start != null) setState(() => _preview = _buildShape(start, p));
  }

  void _onPanEnd(DragEndDetails d) {
    if (_activeStroke != null) {
      setState(() => _activeStroke = null);
      return;
    }
    final preview = _preview;
    if (preview != null) {
      _pushUndo();
      setState(() {
        _annotations.add(preview);
        _selectedId = preview.id;
        _preview = null;
        _shapeStart = null;
      });
    } else {
      setState(() => _shapeStart = null);
    }
  }

  Annotation _buildShape(Offset a, Offset b) {
    if (_tool == _Tool.line || _tool == _Tool.arrow) {
      return LineAnnotation(
        page: _currentPage - 1,
        color: _color,
        from: a,
        to: b,
        strokeWidth: _strokeFrac,
        arrow: _tool == _Tool.arrow,
        opacity: _opacity,
      );
    }
    return ShapeAnnotation(
      page: _currentPage - 1,
      color: _color,
      bounds: Rect.fromPoints(a, b),
      strokeWidth: _strokeFrac,
      ellipse: _tool == _Tool.ellipse,
      fillColor: _useFill ? (_fill ?? _color) : null,
      opacity: _opacity,
    );
  }

  Future<void> _onTapUp(TapUpDetails d) async {
    final p = _toFrac(d.localPosition);
    switch (_tool) {
      case _Tool.select:
        setState(() => _selectedId = _hitTest(p)?.id);
      case _Tool.text:
        await _placeText(p);
      case _Tool.sticky:
        await _placeSticky(p);
      default:
        break;
    }
  }

  /// Topmost mark under [p]. Last drawn wins, which is what "topmost" means on this canvas.
  Annotation? _hitTest(Offset p) {
    for (final a in _pageMarks.reversed) {
      // A hairline stroke is impossible to hit exactly, so every mark gets a small slop.
      if (a.bounds.inflate(0.015).contains(p)) return a;
    }
    return null;
  }

  // ── Placing text / notes / images ─────────────────────────────────────────

  Future<void> _placeText(Offset at, {TextAnnotation? edit}) async {
    final controller = TextEditingController(text: edit?.text ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).annotateAddText),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(ctx).cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(L10n.of(ctx).ok)),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;

    _pushUndo();
    setState(() {
      if (edit != null) {
        edit.text = text;
      } else {
        final a = TextAnnotation(
          page: _currentPage - 1,
          color: _color,
          bounds: Rect.fromLTWH(at.dx, at.dy, 0.5, _fontFrac * 1.6),
          text: text,
          fontSize: _fontFrac,
          bold: _bold,
          opacity: _opacity,
        );
        _annotations.add(a);
        _selectedId = a.id;
      }
    });
  }

  Future<void> _placeSticky(Offset at, {StickyAnnotation? edit}) async {
    final controller = TextEditingController(text: edit?.text ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).annotateSticky),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            minLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text(L10n.of(ctx).annotateNoteHint,
              style: Theme.of(ctx).textTheme.bodySmall),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(ctx).cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(L10n.of(ctx).ok)),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;

    _pushUndo();
    setState(() {
      if (edit != null) {
        edit.text = text;
      } else {
        final a = StickyAnnotation(
          page: _currentPage - 1,
          color: Colors.amber,
          bounds: Rect.fromLTWH(at.dx, at.dy, 0.05, 0.035),
          text: text,
          opacity: _opacity,
        );
        _annotations.add(a);
        _selectedId = a.id;
      }
    });
  }

  Future<void> _insertImage({required bool signature}) async {
    Uint8List? bytes;
    if (signature) {
      bytes = await SignatureSheet.show(context);
    } else {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
      final path = result?.files.single.path;
      if (path != null) bytes = await File(path).readAsBytes();
    }
    if (bytes == null || !mounted) return;

    // Decoded once here rather than in the painter, which cannot await.
    final decoded = await decodeImageFromList(bytes);
    if (!mounted) return;

    // Placed at a sensible size in the middle of the page, keeping the image's aspect ratio, so
    // a wide signature does not arrive squashed.
    const targetW = 0.35;
    final pageAspect = _pageWidthPt / _pageHeightPt;
    final h = targetW * (decoded.height / decoded.width) * pageAspect;

    _pushUndo();
    final a = ImageAnnotation(
      page: _currentPage - 1,
      bounds: Rect.fromLTWH(
          (1 - targetW) / 2, (1 - h).clamp(0.0, 1.0) / 2, targetW, h.clamp(0.02, 0.9)),
      bytes: bytes,
      isSignature: signature,
      opacity: _opacity,
    );
    setState(() {
      _images[a.id] = decoded;
      _annotations.add(a);
      _selectedId = a.id;
      _tool = _Tool.select;
    });
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (_annotations.isEmpty) {
      NotificationService.showSnackbar(
          text: L10n.current.annotateNothingToSave, color: Colors.orange);
      return;
    }

    final upload = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;

    final baseName =
        'annotated_${widget.file.path.split('/').last.replaceAll(RegExp(r'\.pdf$'), '')}';

    // One request for every PDF annotation in the document. The bloc saves the result, and the
    // listener chains the image stamps onto it if there are any.
    runTool((cancelToken) => AnnotatePdfEvent(
          annotatePdf: AnnotatePdf(
            file: upload,
            outFileName: baseName,
            annotations: _annotations,
            flatten: _flatten,
          ),
          cancelToken: cancelToken,
        ));
  }

  /// Stamps the image marks onto [base], one call each.
  ///
  /// Images stay raster — there is no markup annotation that means "this bitmap" — so they go
  /// through the stamp endpoint after the annotations are written. Usually there are none, or one
  /// signature; the annotations themselves all travelled in a single request.
  Future<File> _stampImages(File base) async {
    final images = _annotations.whereType<ImageAnnotation>().toList();
    if (images.isEmpty) return base;

    var input = base;
    for (final img in images) {
      final dir = await Directory.systemTemp.createTemp('annimg');
      final tmp = File('${dir.path}/${img.id}.png');
      await tmp.writeAsBytes(img.bytes);

      final resp = await PdfService().stampPdf(
        stampPdf: StampPdf(
          outFileName: input.path.split('/').last.replaceAll(RegExp(r'\.pdf$'), ''),
          opacity: img.opacity,
          fromPage: img.page,
          toPage: img.page,
          xFrac: img.bounds.left,
          yFrac: img.bounds.top,
          widthFrac: img.bounds.width,
          heightFrac: img.bounds.height,
          file: await MultipartFile.fromFile(input.path),
          stamp: await MultipartFile.fromFile(tmp.path,
              contentType: DioMediaType.parse('image/png')),
        ),
      );
      final data = resp.data;
      if (data != null) {
        final out = File(input.path);
        await out.writeAsBytes(data);
        input = out;
      }
      await dir.delete(recursive: true);
    }
    FileStore().changed();
    return input;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L10n.of(context);
    final pagesWithMarks = _annotations.map((a) => a.page).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_totalPages > 0
            ? l.annotateTitlePage(
                ToolStrings.name(context, 'annotate'), _currentPage, _totalPages)
            : ToolStrings.name(context, 'annotate')),
        actions: [
          IconButton(
              icon: const Icon(Icons.undo),
              tooltip: l.undo,
              onPressed: _undo.isEmpty ? null : () => _restore(_undo, _redo)),
          IconButton(
              icon: const Icon(Icons.redo),
              tooltip: l.redo,
              onPressed: _redo.isEmpty ? null : () => _restore(_redo, _undo)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onSelected: (v) => _insertImage(signature: v == 'sig'),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'sig', child: Text(L10n.of(ctx).annotateSignature)),
              PopupMenuItem(value: 'img', child: Text(L10n.of(ctx).annotateImage)),
            ],
          ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.annotatePdf] != c.httpStates[HttpStates.annotatePdf],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.annotatePdf] != c.httpStates[HttpStates.annotatePdf],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.annotatePdf];
          if (s?.done != true && s?.error == null) return;
          handleToolState(
            s,
            successMessage: L10n.current.annotateSaved,
            // The saved PDF still needs its image marks stamped on before it is shown, so this
            // screen does the navigation — which is why the snackbar must not also offer it.
            onDone: (saved) => unawaited(_finish(saved)),
            offerNextTool: false,
          );
          resetToolState([HttpStates.annotatePdf]);
        },
        builder: (context, state) {
          final busy = _saving || state.httpStates[HttpStates.annotatePdf]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvas(theme),
              ),
              if (_totalPages > 1) _buildPageNav(theme, pagesWithMarks),
              _buildToolbar(theme),
              _buildOptions(theme),
              _buildSaveBar(theme, busy),
            ]),
            processingOverlay(state.httpStates[HttpStates.annotatePdf],
                label: L10n.of(context).annotateSaving),
          ]);
        },
      ),
    );
  }

  Future<void> _finish(File saved) async {
    setState(() => _saving = true);
    try {
      final withImages = await _stampImages(saved);
      if (!mounted) return;
      GoRouter.of(context).pushNamed(
        AppRoutes.pdfFilePreviewRoute.name,
        pathParameters: {'pdfFilePath': withImages.path},
        queryParameters: const {'from': 'tool'},
      );
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.saveFailedWith('$e'), color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Canvas ────────────────────────────────────────────────────────────────

  Widget _buildCanvas(ThemeData theme) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final pageAspect = _pageWidthPt / _pageHeightPt;
      final canvasAspect = constraints.maxWidth / constraints.maxHeight;
      final double w, h;
      if (pageAspect > canvasAspect) {
        w = constraints.maxWidth;
        h = constraints.maxWidth / pageAspect;
      } else {
        h = constraints.maxHeight;
        w = constraints.maxHeight * pageAspect;
      }
      _canvasSize = Size(w, h);
      final marks = _pageMarks;

      return Center(
        // One viewer over the page *and* the marks. Previously the InteractiveViewer wrapped only
        // the overlay, so zooming moved the marks and left the page behind — they came away from
        // the content they were annotating.
        child: InteractiveViewer(
          transformationController: _tc,
          minScale: 1,
          maxScale: 6,
          // Panning would fight the drawing gesture; pinch still zooms, and at 1× there is
          // nothing to pan anyway.
          panEnabled: _tool == _Tool.select,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              // The page is drawn by the painter, not as a widget underneath it, so blend modes
              // have the page in their own layer to work against.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _tool == _Tool.select ? null : _onPanStart,
                  onPanUpdate: _tool == _Tool.select ? null : _onPanUpdate,
                  onPanEnd: _tool == _Tool.select ? null : _onPanEnd,
                  onTapUp: _onTapUp,
                  child: CustomPaint(
                    painter: AnnotationPainter(
                      page: _pageDecoded,
                      annotations: marks,
                      selectedId: _selectedId,
                      preview: _preview,
                      imageCache: _images,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              if (_tool == _Tool.select && _selected != null) ..._buildHandles(_selected!),
            ]),
          ),
        ),
      );
    });
  }

  /// Move body plus four corner handles for the selected mark.
  ///
  /// The sizes come from the form editor's field handles
  /// (`form_editor_view.dart`): a 26px dot inside a 48dp touch target, pushed outwards per axis
  /// when the mark is smaller than the handles themselves — otherwise four dots bury a small note
  /// and close into a solid cluster over the thing being edited.
  List<Widget> _buildHandles(Annotation a) {
    const box = 48.0;
    const dot = 26.0;
    const half = box / 2;
    const clearance = 22.0;

    final r = _toPx(a.bounds);
    final outX = math.max(0.0, (dot + clearance - r.width) / 2);
    final outY = math.max(0.0, (dot + clearance - r.height) / 2);

    void resize(Offset deltaPx, {required bool left, required bool top}) {
      final d = Offset(deltaPx.dx / _canvasSize.width, deltaPx.dy / _canvasSize.height);
      var b = a.bounds;
      var l = b.left + (left ? d.dx : 0);
      var t = b.top + (top ? d.dy : 0);
      var right = b.right + (left ? 0 : d.dx);
      var bottom = b.bottom + (top ? 0 : d.dy);
      // A mark dragged inside-out would flip; a minimum keeps it grabbable.
      const min = 0.01;
      if (right - l < min) left ? l = right - min : right = l + min;
      if (bottom - t < min) top ? t = bottom - min : bottom = t + min;

      var next = Rect.fromLTRB(l, t, right, bottom);
      if (a.lockAspect) {
        final ratio = b.height == 0 ? 1.0 : b.width / b.height;
        final width = next.width;
        next = Rect.fromLTWH(next.left, next.top, width, width / math.max(ratio, 0.0001));
      }
      setState(() => a.bounds = next);
    }

    Widget handle(double left, double top, IconData icon, void Function(Offset) onDrag) {
      return Positioned(
        left: left - half,
        top: top - half,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _pushUndo(),
          onPanUpdate: (d) => onDrag(d.delta),
          child: Container(
            width: box,
            height: box,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
          ),
        ),
      );
    }

    return [
      // Drag the body to move.
      Positioned(
        left: r.left,
        top: r.top,
        width: math.max(r.width, 1),
        height: math.max(r.height, 1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _pushUndo(),
          onPanUpdate: (d) {
            final dx = d.delta.dx / _canvasSize.width;
            final dy = d.delta.dy / _canvasSize.height;
            setState(() => a.bounds = a.bounds.translate(dx, dy));
          },
          onTap: () {
            // A second tap on an already-selected note or text opens it for editing.
            final sel = a;
            if (sel is TextAnnotation) _placeText(sel.bounds.topLeft, edit: sel);
            if (sel is StickyAnnotation) _placeSticky(sel.bounds.topLeft, edit: sel);
          },
        ),
      ),
      handle(r.left - outX, r.top - outY, Icons.north_west,
          (d) => resize(d, left: true, top: true)),
      handle(r.right + outX, r.top - outY, Icons.north_east,
          (d) => resize(d, left: false, top: true)),
      handle(r.left - outX, r.bottom + outY, Icons.south_west,
          (d) => resize(d, left: true, top: false)),
      handle(r.right + outX, r.bottom + outY, Icons.south_east,
          (d) => resize(d, left: false, top: false)),
    ];
  }

  // ── Page navigation ───────────────────────────────────────────────────────

  Widget _buildPageNav(ThemeData theme, int pagesWithMarks) {
    final marked = _annotations.map((a) => a.page).toSet();
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
        ),
        // A strip of every page, marked ones dotted — so "which pages have I annotated?" is
        // answerable without paging through the document.
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _totalPages,
              itemBuilder: (context, i) {
                final n = i + 1;
                final isCurrent = n == _currentPage;
                return GestureDetector(
                  onTap: () => _loadPage(n),
                  child: Container(
                    width: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.surface),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      Text('$n',
                          style: TextStyle(
                              fontSize: 12,
                              color: isCurrent ? Colors.white : theme.colorScheme.onSurface)),
                      if (marked.contains(i))
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: isCurrent ? Colors.white : theme.colorScheme.primary,
                                shape: BoxShape.circle),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages ? () => _loadPage(_currentPage + 1) : null,
        ),
      ]),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          _toolBtn(_Tool.select, Icons.near_me_outlined, L10n.of(context).annotateSelect, theme),
          _divider(),
          _toolBtn(_Tool.pen, Icons.edit_outlined, L10n.of(context).annotatePen, theme),
          _toolBtn(_Tool.highlighter, Icons.highlight_outlined,
              L10n.of(context).annotateHighlight, theme),
          _divider(),
          _toolBtn(_Tool.text, Icons.text_fields, L10n.of(context).annotateText, theme),
          _toolBtn(_Tool.sticky, Icons.sticky_note_2_outlined,
              L10n.of(context).annotateSticky, theme),
          _divider(),
          _toolBtn(_Tool.rect, Icons.crop_square_outlined,
              L10n.of(context).annotateRectangle, theme),
          _toolBtn(_Tool.ellipse, Icons.circle_outlined,
              L10n.of(context).annotateEllipse, theme),
          _toolBtn(_Tool.line, Icons.remove, L10n.of(context).annotateLine, theme),
          _toolBtn(_Tool.arrow, Icons.arrow_forward_outlined,
              L10n.of(context).annotateArrow, theme),
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
        style: active
            ? IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15))
            : null,
        onPressed: () => setState(() {
          _tool = t;
          if (t != _Tool.select) _selectedId = null;
        }),
      ),
    );
  }

  Widget _divider() => const SizedBox(
      height: 32, child: VerticalDivider(width: 16, indent: 4, endIndent: 4));

  // ── Options ───────────────────────────────────────────────────────────────

  /// Style controls. In select mode they edit the selected mark; otherwise they set what the next
  /// mark will be. One panel either way, so the controls do not move around.
  Widget _buildOptions(ThemeData theme) {
    final l = L10n.of(context);
    final sel = _tool == _Tool.select ? _selected : null;

    if (_tool == _Tool.select && sel == null) {
      return Container(
        width: double.infinity,
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(l.annotateNoSelection,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    final color = sel?.color ?? _color;
    final opacity = sel?.opacity ?? _opacity;
    final isText = sel is TextAnnotation || (sel == null && _tool == _Tool.text);
    final showStroke = sel is InkAnnotation ||
        sel is ShapeAnnotation ||
        sel is LineAnnotation ||
        (sel == null && _tool != _Tool.text && _tool != _Tool.sticky);

    /// A discrete edit: one undo step.
    void mutate(void Function() change) {
      if (sel != null) _pushUndo();
      setState(change);
    }

    /// A slider edit. The undo step is pushed when the drag *starts*, not on every tick —
    /// otherwise one drag of the opacity slider buried the user's actual work under fifty
    /// identical undo entries.
    void slide(void Function() change) => setState(change);
    void slideStart() {
      if (sel != null) _pushUndo();
    }

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          for (final c in [
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.black,
            Colors.orange,
            Colors.purple
          ])
            GestureDetector(
              onTap: () => mutate(() {
                if (sel != null) {
                  sel.color = c;
                } else {
                  _color = c;
                }
              }),
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: color.toARGB32() == c.toARGB32()
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2),
                ),
              ),
            ),
          const Spacer(),
          if (sel != null) ...[
            IconButton(
              icon: const Icon(Icons.content_copy_outlined, size: 20),
              tooltip: l.annotateDuplicate,
              onPressed: () {
                _pushUndo();
                setState(() {
                  final copy = sel.duplicate()..bounds = sel.bounds.translate(0.02, 0.02);
                  if (sel is ImageAnnotation) _images[copy.id] = _images[sel.id]!;
                  _annotations.add(copy);
                  _selectedId = copy.id;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: l.annotateDeleteMark,
              onPressed: () {
                _pushUndo();
                setState(() {
                  _annotations.removeWhere((a) => a.id == sel.id);
                  // The decoded image deliberately stays in the cache. Undo restores the
                  // annotation, and the cache is keyed by its id — evicting here meant an
                  // undone deletion came back as an empty placeholder box.
                  _selectedId = null;
                });
              },
            ),
          ],
        ]),
        Row(children: [
          Icon(Icons.opacity, size: 18, color: theme.colorScheme.onSurfaceVariant),
          Expanded(
            child: Slider(
              value: opacity,
              min: 0.1,
              max: 1.0,
              onChangeStart: (_) => slideStart(),
              onChanged: (v) => slide(() {
                if (sel != null) {
                  sel.opacity = v;
                } else {
                  _opacity = v;
                }
              }),
            ),
          ),
          if (showStroke) ...[
            Icon(Icons.line_weight, size: 18, color: theme.colorScheme.onSurfaceVariant),
            Expanded(
              child: Slider(
                value: _strokeOf(sel),
                min: 0.001,
                max: 0.02,
                onChangeStart: (_) => slideStart(),
                onChanged: (v) => slide(() => _setStroke(sel, v)),
              ),
            ),
          ],
          if (isText) ...[
            Icon(Icons.format_size, size: 18, color: theme.colorScheme.onSurfaceVariant),
            Expanded(
              child: Slider(
                value: sel is TextAnnotation ? sel.fontSize : _fontFrac,
                min: 0.008,
                max: 0.08,
                onChangeStart: (_) => slideStart(),
                onChanged: (v) => slide(() {
                  if (sel is TextAnnotation) {
                    sel.fontSize = v;
                  } else {
                    _fontFrac = v;
                  }
                }),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  double _strokeOf(Annotation? sel) => switch (sel) {
        InkAnnotation a => a.strokeWidth.clamp(0.001, 0.02),
        ShapeAnnotation a => a.strokeWidth.clamp(0.001, 0.02),
        LineAnnotation a => a.strokeWidth.clamp(0.001, 0.02),
        _ => _strokeFrac,
      };

  void _setStroke(Annotation? sel, double v) {
    switch (sel) {
      case InkAnnotation a:
        a.strokeWidth = v;
      case ShapeAnnotation a:
        a.strokeWidth = v;
      case LineAnnotation a:
        a.strokeWidth = v;
      default:
        _strokeFrac = v;
    }
  }

  Widget _buildSaveBar(ThemeData theme, bool busy) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: busy ? null : () => setState(() => _flatten = !_flatten),
          child: Row(children: [
            Checkbox(
              value: _flatten,
              onChanged: busy ? null : (v) => setState(() => _flatten = v ?? false),
            ),
            Expanded(
              child: Text(
                _flatten
                    ? L10n.of(context).annotateFlattenOn
                    : L10n.of(context).annotateFlattenOff,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : _onSave,
            icon: const Icon(Icons.save_alt),
            label: Text(L10n.of(context).exportPdf),
          ),
        ),
      ]),
    );
  }
}
