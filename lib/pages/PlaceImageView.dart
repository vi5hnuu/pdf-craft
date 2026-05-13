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

/// Shared view for placing any image at a user-chosen position/size on a PDF page.
/// Used by QR Stamp (preloaded image bytes) and Image Overlay (user picks image).
class PlaceImageView extends StatefulWidget {
  final File pdfFile;
  // preloaded bytes are provided by QR Stamp; null = user picks via file picker (Image Overlay)
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
  // PDF state
  PdfDocument? _doc;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfPageImage? _pageImage;
  double _pageWidthPt = 595;
  double _pageHeightPt = 842;
  bool _loadingPage = true;

  // Image overlay state (fractions of canvas/page, 0.0–1.0)
  Uint8List? _imageBytes;
  double _xFrac = 0.1;
  double _yFrac = 0.1;
  double _wFrac = 0.4;
  double _hFrac = 0.4;
  double _aspectRatio = 1.0; // imageW / imageH in pixels
  bool _lockAspect = true;

  static const double _handleSize = 20.0;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    if (widget.preloadedImageBytes != null) {
      _decodeImageSize(widget.preloadedImageBytes!);
    }
    _openDocument();
  }

  Future<void> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _aspectRatio = img.width / img.height;
        // Keep width fixed at 0.4, adjust height to match image aspect
        _hFrac = _wFrac / _aspectRatio;
      });
    }
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
    final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();
    await _decodeImageSize(bytes);
  }

  Future<void> _onConfirm() async {
    if (_imageBytes == null) {
      NotificationService.showSnackbar(text: 'Please select an image first', color: Colors.orange);
      return;
    }

    // Clamp fractions to valid range
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title}${_totalPages > 1 ? ' — Page $_currentPage / $_totalPages' : ''}'),
        actions: [
          // Aspect ratio lock toggle
          if (_imageBytes != null)
            IconButton(
              icon: Icon(_lockAspect ? Icons.lock : Icons.lock_open),
              tooltip: _lockAspect ? 'Aspect ratio locked' : 'Aspect ratio free',
              onPressed: () => setState(() => _lockAspect = !_lockAspect),
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
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Placing image…', color: Colors.lightBlue);
          }
        },
        builder: (context, state) {
          return Stack(children: [
            Column(children: [
              // Image picker button (only when no preloaded image)
              if (widget.preloadedImageBytes == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_imageBytes == null ? 'Select Image to Place' : 'Change Image'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ),

              // Canvas
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvas(theme),
              ),

              // Page navigation
              if (_totalPages > 1) _buildPageNav(theme),

              // Confirm bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton.icon(
                  onPressed: _imageBytes == null ? null : _onConfirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm Placement'),
                ),
              ),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.PLACE_IMAGE]),
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

      // Image overlay pixel positions
      final ox = _xFrac * imgW;
      final oy = _yFrac * imgH;
      final ow = _wFrac * imgW;
      final oh = _hFrac * imgH;

      return Center(
        child: SizedBox(
          width: imgW,
          height: imgH,
          child: Stack(children: [
            // PDF page background
            if (_pageImage != null)
              Positioned.fill(child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill))
            else
              Positioned.fill(child: Container(color: Colors.white)),

            // Instruction hint when no image yet
            if (_imageBytes == null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Select an image above to position it on this page',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

            // Draggable image overlay
            if (_imageBytes != null)
              Positioned(
                left: ox,
                top: oy,
                width: ow,
                height: oh,
                child: GestureDetector(
                  // Drag whole image to reposition
                  onPanUpdate: (d) => setState(() {
                    _xFrac = (_xFrac + d.delta.dx / imgW).clamp(0.0, 1.0 - _wFrac);
                    _yFrac = (_yFrac + d.delta.dy / imgH).clamp(0.0, 1.0 - _hFrac);
                  }),
                  child: Stack(children: [
                    // Image itself
                    Positioned.fill(
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.fill,
                      ),
                    ),
                    // Dashed border
                    Positioned.fill(child: _DashedBorder()),
                    // Move indicator
                    const Center(
                      child: Icon(Icons.open_with, color: Colors.white70, size: 24),
                    ),
                    // SE corner resize handle
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() {
                          _wFrac = (_wFrac + d.delta.dx / imgW).clamp(0.02, 1.0 - _xFrac);
                          if (_lockAspect) {
                            _hFrac = _wFrac * imgW / (imgH * _aspectRatio);
                          } else {
                            _hFrac = (_hFrac + d.delta.dy / imgH).clamp(0.02, 1.0 - _yFrac);
                          }
                        }),
                        child: Container(
                          width: _handleSize,
                          height: _handleSize,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                    // NE corner resize handle
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() {
                          final newW = (_wFrac + d.delta.dx / imgW).clamp(0.02, 1.0 - _xFrac);
                          final newH = (_hFrac - d.delta.dy / imgH).clamp(0.02, _yFrac + _hFrac);
                          if (_lockAspect) {
                            _wFrac = newW;
                            _hFrac = _wFrac * imgW / (imgH * _aspectRatio);
                            _yFrac = (_yFrac + _hFrac - _hFrac).clamp(0.0, 1.0);
                          } else {
                            _wFrac = newW;
                            _yFrac = (_yFrac + (_hFrac - newH)).clamp(0.0, 1.0);
                            _hFrac = newH;
                          }
                        }),
                        child: Container(
                          width: _handleSize,
                          height: _handleSize,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ]),
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

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
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
        final end = (drawn + dashLen).clamp(0, len);
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
