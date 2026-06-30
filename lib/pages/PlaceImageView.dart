import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/place-image.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

enum _Mode { place, zoom }

/// Shared view for placing any image at a user-chosen position/size on a PDF page.
/// Supports pinch-zoom for precision placement, freeform resize with 4 corner handles,
/// and an aspect-ratio lock toggle in the bottom bar.
class PlaceImageView extends StatefulWidget {
  final File pdfFile;
  final Uint8List? preloadedImageBytes;
  final String title;

  const PlaceImageView({
    super.key,
    required this.pdfFile,
    this.preloadedImageBytes,
    this.title = 'Place Image',
  });

  @override
  State<PlaceImageView> createState() => _PlaceImageViewState();
}

class _PlaceImageViewState extends State<PlaceImageView> {
  // PDF page
  PdfDocument? _doc;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfPageImage? _pageImage;
  double _pageWidthPt = 595;
  double _pageHeightPt = 842;
  bool _loadingPage = true;

  // Image overlay — fractions of canvas dimensions (0.0–1.0)
  Uint8List? _imageBytes;
  double _xFrac = 0.25;
  double _yFrac = 0.25;
  double _wFrac = 0.5;
  double _hFrac = 0.5;
  double _aspectRatio = 1.0; // original image pixelW / pixelH
  bool _lockAspect = true;

  // Zoom / placement mode
  _Mode _mode = _Mode.place;
  final TransformationController _txCtrl = TransformationController();

  // Cached canvas dimensions from last LayoutBuilder (needed for delta scaling)
  double _canvasW = 1;
  double _canvasH = 1;

  static const double _handleSize = 22.0;
  static const double _minFrac = 0.02;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    if (widget.preloadedImageBytes != null) {
      _decodeAndCenter(widget.preloadedImageBytes!);
    }
    _openDocument();
  }

  Future<void> _decodeAndCenter(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final ar = img.width / img.height;
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _aspectRatio = ar;
      // Default to 50% width; adjust height to maintain aspect
      _wFrac = 0.5;
      _hFrac = _canvasW > 1
          ? _wFrac * _canvasW / (_canvasH * ar)
          : 0.5 / ar;
      _hFrac = _hFrac.clamp(_minFrac, 0.9);
      // Center on the page
      _xFrac = (1 - _wFrac) / 2;
      _yFrac = (1 - _hFrac) / 2;
    });
  }

  Future<void> _openDocument() async {
    try {
      _doc = await PdfDocument.openFile(widget.pdfFile.path);
      _totalPages = _doc!.pagesCount;
      await _loadPage(1);
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

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes ??
        await File(result.files.first.path!).readAsBytes();
    await _decodeAndCenter(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title}${_totalPages > 1 ? ' — Page $_currentPage / $_totalPages' : ''}'),
        actions: [
          // Mode toggle: place ↔ zoom
          IconButton(
            icon: Icon(
              _mode == _Mode.zoom ? Icons.touch_app : Icons.zoom_in,
            ),
            tooltip: _mode == _Mode.zoom ? 'Switch to Place mode' : 'Switch to Zoom mode',
            onPressed: () => setState(() => _mode = _mode == _Mode.place ? _Mode.zoom : _Mode.place),
          ),
          // Reset zoom
          if (_mode == _Mode.zoom)
            IconButton(
              icon: const Icon(Icons.fit_screen),
              tooltip: 'Reset zoom',
              onPressed: () => _txCtrl.value = Matrix4.identity(),
            ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.PLACE_IMAGE] != c.httpStates[HttpStates.PLACE_IMAGE],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.PLACE_IMAGE] != c.httpStates[HttpStates.PLACE_IMAGE],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.PLACE_IMAGE];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Image placed successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {
                  'pdfFilePath': (s!.extras!['savedFile'] as File).path,
                },
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          return Stack(children: [
            Column(children: [
              // Image picker button (only when no preloaded image)
              if (widget.preloadedImageBytes == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_imageBytes == null ? 'Select Image to Place' : 'Change Image'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  ),
                ),

              // Mode hint chip
              if (_imageBytes != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(children: [
                    Chip(
                      avatar: Icon(
                        _mode == _Mode.zoom ? Icons.zoom_in : Icons.open_with,
                        size: 16,
                      ),
                      label: Text(
                        _mode == _Mode.zoom
                            ? 'Zoom mode — pinch or scroll to zoom'
                            : 'Place mode — drag image or handles',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ]),
                ),

              // Canvas
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvas(theme),
              ),

              // Page navigation
              if (_totalPages > 1) _buildPageNav(theme),

              // Bottom bar: aspect lock + confirm
              _buildBottomBar(theme, state),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.PLACE_IMAGE], label: 'Placing image'),
          ]);
        },
      ),
    );
  }

  Widget _buildCanvas(ThemeData theme) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final canvasW = constraints.maxWidth;
      final canvasH = constraints.maxHeight;

      // Fit page maintaining aspect ratio
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

      // Cache canvas dims for use in drag delta scaling
      _canvasW = imgW;
      _canvasH = imgH;

      // Pixel positions of overlay image inside the canvas
      final ox = _xFrac * imgW;
      final oy = _yFrac * imgH;
      final ow = _wFrac * imgW;
      final oh = _hFrac * imgH;

      return Center(
        child: SizedBox(
          width: imgW,
          height: imgH,
          child: InteractiveViewer(
            transformationController: _txCtrl,
            panEnabled: _mode == _Mode.zoom,
            scaleEnabled: _mode == _Mode.zoom,
            minScale: 0.5,
            maxScale: 8.0,
            child: SizedBox(
              width: imgW,
              height: imgH,
              child: Stack(clipBehavior: Clip.none, children: [
                // PDF page background
                if (_pageImage != null)
                  Positioned.fill(child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill))
                else
                  Positioned.fill(child: Container(color: Colors.white)),

                // Instruction when no image yet
                if (_imageBytes == null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        'Select an image above\nto position it on this page',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                // Draggable / resizable image overlay
                if (_imageBytes != null)
                  Positioned(
                    left: ox,
                    top: oy,
                    width: ow,
                    height: oh,
                    child: _buildImageOverlay(imgW, imgH, ow, oh, theme),
                  ),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildImageOverlay(double imgW, double imgH, double ow, double oh, ThemeData theme) {
    // In zoom mode, handles are passive (no interaction)
    final interactive = _mode == _Mode.place;

    return Stack(clipBehavior: Clip.none, children: [
      // Image body — drag to reposition
      Positioned.fill(
        child: GestureDetector(
          behavior: interactive ? HitTestBehavior.opaque : HitTestBehavior.translucent,
          onPanUpdate: !interactive ? null : (d) {
            final scale = _txCtrl.value.getMaxScaleOnAxis();
            setState(() {
              _xFrac = (_xFrac + d.delta.dx / (imgW * scale)).clamp(0.0, 1.0 - _wFrac);
              _yFrac = (_yFrac + d.delta.dy / (imgH * scale)).clamp(0.0, 1.0 - _hFrac);
            });
          },
          child: Stack(children: [
            Positioned.fill(child: Image.memory(_imageBytes!, fit: BoxFit.fill)),
            const Positioned.fill(child: _DashedBorder()),
            // Move icon at center
            const Center(child: Icon(Icons.open_with, color: Colors.white70, size: 22)),
          ]),
        ),
      ),

      // NW corner handle — move top-left corner
      if (interactive)
        Positioned(
          left: -_handleSize / 2,
          top: -_handleSize / 2,
          child: _ResizeHandle(
            color: theme.colorScheme.primary,
            onDelta: (dx, dy) {
              final scale = _txCtrl.value.getMaxScaleOnAxis();
              final dxF = dx / (imgW * scale);
              final dyF = dy / (imgH * scale);
              setState(() {
                final newW = (_wFrac - dxF).clamp(_minFrac, _xFrac + _wFrac);
                final newH = _lockAspect
                    ? newW * imgW / (imgH * _aspectRatio)
                    : (_hFrac - dyF).clamp(_minFrac, _yFrac + _hFrac);
                _xFrac = (_xFrac + (_wFrac - newW)).clamp(0.0, 1.0);
                _yFrac = (_yFrac + (_hFrac - newH)).clamp(0.0, 1.0);
                _wFrac = newW;
                _hFrac = newH;
              });
            },
          ),
        ),

      // NE corner handle — move top-right corner
      if (interactive)
        Positioned(
          right: -_handleSize / 2,
          top: -_handleSize / 2,
          child: _ResizeHandle(
            color: theme.colorScheme.primary,
            onDelta: (dx, dy) {
              final scale = _txCtrl.value.getMaxScaleOnAxis();
              final dxF = dx / (imgW * scale);
              final dyF = dy / (imgH * scale);
              setState(() {
                final newW = (_wFrac + dxF).clamp(_minFrac, 1.0 - _xFrac);
                final newH = _lockAspect
                    ? newW * imgW / (imgH * _aspectRatio)
                    : (_hFrac - dyF).clamp(_minFrac, _yFrac + _hFrac);
                final newY = _lockAspect
                    ? (_yFrac + (_hFrac - newH)).clamp(0.0, 1.0)
                    : (_yFrac + (_hFrac - newH)).clamp(0.0, 1.0);
                _wFrac = newW;
                _hFrac = newH;
                _yFrac = newY;
              });
            },
          ),
        ),

      // SW corner handle — move bottom-left corner
      if (interactive)
        Positioned(
          left: -_handleSize / 2,
          bottom: -_handleSize / 2,
          child: _ResizeHandle(
            color: theme.colorScheme.primary,
            onDelta: (dx, dy) {
              final scale = _txCtrl.value.getMaxScaleOnAxis();
              final dxF = dx / (imgW * scale);
              final dyF = dy / (imgH * scale);
              setState(() {
                final newW = (_wFrac - dxF).clamp(_minFrac, _xFrac + _wFrac);
                final newH = _lockAspect
                    ? newW * imgW / (imgH * _aspectRatio)
                    : (_hFrac + dyF).clamp(_minFrac, 1.0 - _yFrac);
                _xFrac = (_xFrac + (_wFrac - newW)).clamp(0.0, 1.0);
                _wFrac = newW;
                _hFrac = newH;
              });
            },
          ),
        ),

      // SE corner handle — move bottom-right corner
      if (interactive)
        Positioned(
          right: -_handleSize / 2,
          bottom: -_handleSize / 2,
          child: _ResizeHandle(
            color: theme.colorScheme.secondary,
            onDelta: (dx, dy) {
              final scale = _txCtrl.value.getMaxScaleOnAxis();
              final dxF = dx / (imgW * scale);
              final dyF = dy / (imgH * scale);
              setState(() {
                final newW = (_wFrac + dxF).clamp(_minFrac, 1.0 - _xFrac);
                final newH = _lockAspect
                    ? newW * imgW / (imgH * _aspectRatio)
                    : (_hFrac + dyF).clamp(_minFrac, 1.0 - _yFrac);
                _wFrac = newW;
                _hFrac = newH;
              });
            },
          ),
        ),
    ]);
  }

  Widget _buildBottomBar(ThemeData theme, PdfState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(children: [
        // Aspect lock toggle
        OutlinedButton.icon(
          onPressed: () => setState(() => _lockAspect = !_lockAspect),
          icon: Icon(_lockAspect ? Icons.lock : Icons.lock_open, size: 18),
          label: Text(_lockAspect ? 'Locked' : 'Free'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _lockAspect ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            side: BorderSide(
              color: _lockAspect ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _imageBytes == null ? null : _onConfirm,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm Placement'),
          ),
        ),
      ]),
    );
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
            onPressed: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
          ),
          Text('$_currentPage / $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages ? () => _loadPage(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    if (_imageBytes == null) return;
    final x = _xFrac.clamp(0.0, 1.0);
    final y = _yFrac.clamp(0.0, 1.0);
    final w = _wFrac.clamp(0.01, 1.0 - x);
    final h = _hFrac.clamp(0.01, 1.0 - y);
    final pdfName = widget.pdfFile.path.split('/').last.replaceAll('.pdf', '');

    BlocProvider.of<PdfBloc>(context).add(PlaceImageEvent(
      placeImage: PlaceImage(
        outFileName: '${pdfName}_image',
        page: _currentPage - 1,
        xFrac: x,
        yFrac: y,
        widthFrac: w,
        heightFrac: h,
        file: await MultipartFile.fromFile(widget.pdfFile.path),
        image: MultipartFile.fromBytes(
          _imageBytes!,
          filename: 'image.png',
          contentType: DioMediaType.parse('image/png'),
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    _doc?.close();
    super.dispose();
  }
}

// ── Reusable resize handle widget ─────────────────────────────────────────────

class _ResizeHandle extends StatelessWidget {
  final Color color;
  final void Function(double dx, double dy) onDelta;

  const _ResizeHandle({required this.color, required this.onDelta});

  static const double _size = 22.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => onDelta(d.delta.dx, d.delta.dy),
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
      ),
    );
  }
}

// ── Dashed border painter ─────────────────────────────────────────────────────

class _DashedBorder extends StatelessWidget {
  const _DashedBorder();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DashedBorderPainter());
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashLen = 6.0;
    const gapLen = 4.0;

    void drawDashedLine(Offset a, Offset b) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len = (b - a).distance;
      double drawn = 0;
      while (drawn < len) {
        final end = (drawn + dashLen).clamp(0.0, len);
        canvas.drawLine(
          Offset(a.dx + dx * drawn / len, a.dy + dy * drawn / len),
          Offset(a.dx + dx * end / len, a.dy + dy * end / len),
          paint,
        );
        drawn += dashLen + gapLen;
      }
    }

    drawDashedLine(Offset.zero, Offset(size.width, 0));
    drawDashedLine(Offset(size.width, 0), Offset(size.width, size.height));
    drawDashedLine(Offset(size.width, size.height), Offset(0, size.height));
    drawDashedLine(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}
