import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

/// Create a signature — either by drawing it or importing an image — then
/// navigate to PlaceImageView to drag/resize and stamp it onto the PDF.
///
/// The drawn signature is exported **cropped to its ink bounds with a
/// transparent background** (previously the whole white canvas was captured, so
/// the signature ended up tiny inside a large white block). Strokes are smoothed
/// with quadratic beziers for a natural pen feel.
class SignPdfView extends StatefulWidget {
  final File file;
  const SignPdfView({super.key, required this.file});

  @override
  State<SignPdfView> createState() => _SignPdfViewState();
}

class _SignPdfViewState extends State<SignPdfView> {
  // Each stroke is a list of offsets; null marks a pen-up between strokes.
  final List<List<Offset?>> _strokes = [];
  Color _inkColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _busy = false;

  static const _colorOptions = [
    Colors.black,
    Color(0xFF1565C0), // blue-ink
    Color(0xFFC62828), // red-ink
  ];

  bool get _hasStrokes => _strokes.any((s) => s.any((p) => p != null));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _hasStrokes ? () => setState(() => _strokes.removeLast()) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _hasStrokes ? () => setState(_strokes.clear) : null,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(
                'Draw your signature below, or import one from your device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 12),
              // Signature canvas — a card with a guide line, like a signing pad.
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    // Signature guide line.
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 48,
                      child: Row(children: [
                        Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Expanded(child: Container(height: 1.5, color: Colors.grey.shade300)),
                      ]),
                    ),
                    if (!_hasStrokes)
                      Center(
                        child: Text('Sign here',
                            style: TextStyle(color: Colors.grey.shade300, fontSize: 28, fontStyle: FontStyle.italic)),
                      ),
                    GestureDetector(
                      onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                      onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
                      onPanEnd: (_) => setState(() => _strokes.last.add(null)),
                      child: CustomPaint(
                        painter: _SignaturePainter(_strokes, _inkColor, _strokeWidth),
                        size: Size.infinite,
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        // Ink controls.
        Container(
          color: theme.cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            ..._colorOptions.map((c) => GestureDetector(
                  onTap: () => setState(() => _inkColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _inkColor == c ? theme.colorScheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                )),
            const SizedBox(width: 8),
            Icon(Icons.line_weight, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            Expanded(
              child: Slider(
                value: _strokeWidth,
                min: 1.0,
                max: 8.0,
                divisions: 7,
                label: _strokeWidth.round().toString(),
                onChanged: (v) => setState(() => _strokeWidth = v),
              ),
            ),
          ]),
        ),
        // Actions.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _importSignature,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Import'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (_hasStrokes && !_busy) ? _placeDrawn : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Place on PDF'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _placeDrawn() async {
    setState(() => _busy = true);
    try {
      final bytes = await _exportCroppedSignature();
      if (bytes == null) {
        NotificationService.showSnackbar(text: 'Could not capture signature', color: Colors.red);
        return;
      }
      if (!mounted) return;
      GoRouter.of(context).pushNamed(
        AppRoutes.placeImageRoute.name,
        extra: {'file': widget.file, 'imageBytes': bytes, 'title': 'Place Signature'},
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSignature() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;
    GoRouter.of(context).pushNamed(
      AppRoutes.placeImageRoute.name,
      extra: {'file': widget.file, 'imageBytes': bytes, 'title': 'Place Signature'},
    );
  }

  /// Renders only the drawn strokes, cropped to their bounding box with padding
  /// and a transparent background, at 3x for crisp stamping.
  Future<Uint8List?> _exportCroppedSignature() async {
    final pts = <Offset>[];
    for (final stroke in _strokes) {
      for (final p in stroke) {
        if (p != null) pts.add(p);
      }
    }
    if (pts.isEmpty) return null;

    double minX = pts.first.dx, maxX = pts.first.dx, minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = p.dx < minX ? p.dx : minX;
      maxX = p.dx > maxX ? p.dx : maxX;
      minY = p.dy < minY ? p.dy : minY;
      maxY = p.dy > maxY ? p.dy : maxY;
    }
    final pad = _strokeWidth * 2 + 12;
    final rect = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
    const scale = 3.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.translate(-rect.left, -rect.top);
    _SignaturePainter(_strokes, _inkColor, _strokeWidth).paint(canvas, rect.size);
    final picture = recorder.endRecording();

    final img = await picture.toImage((rect.width * scale).ceil(), (rect.height * scale).ceil());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  final Color color;
  final double strokeWidth;

  _SignaturePainter(this.strokes, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      // Collect the non-null points for this stroke.
      final points = stroke.whereType<Offset>().toList();
      if (points.isEmpty) continue;
      if (points.length < 3) {
        // Too short to smooth — draw a dot / short line.
        canvas.drawPoints(ui.PointMode.polygon, points, paint);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      // Quadratic beziers through midpoints for a smooth, natural line.
      for (int i = 1; i < points.length - 1; i++) {
        final mid = Offset(
          (points[i].dx + points[i + 1].dx) / 2,
          (points[i].dy + points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
