import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

/// User draws a signature on a blank canvas, then navigates to PlaceImageView
/// to drag/resize and stamp it onto the PDF.
class SignPdfView extends StatefulWidget {
  final File file;
  const SignPdfView({super.key, required this.file});

  @override
  State<SignPdfView> createState() => _SignPdfViewState();
}

class _SignPdfViewState extends State<SignPdfView> {
  final _canvasKey = GlobalKey();
  // Each stroke is a list of offsets; null marks a pen-up between strokes
  final List<List<Offset?>> _strokes = [];
  Color _inkColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _capturing = false;

  static const _colorOptions = [Colors.black, Colors.blue, Colors.red];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStrokes = _strokes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign PDF'),
        actions: [
          if (hasStrokes)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last stroke',
              onPressed: () => setState(() => _strokes.removeLast()),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: hasStrokes ? () => setState(() => _strokes.clear()) : null,
          ),
          TextButton(
            onPressed: hasStrokes && !_capturing ? _onPlace : null,
            child: const Text('Place'),
          ),
        ],
      ),
      body: Column(children: [
        // Ink color + width controls
        Container(
          color: theme.cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Text('Ink: '),
            ...(_colorOptions.map((c) => GestureDetector(
              onTap: () => setState(() => _inkColor = c),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: _inkColor == c
                      ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                      : Border.all(color: Colors.transparent, width: 2.5),
                ),
              ),
            ))),
            const SizedBox(width: 16),
            const Text('Width: '),
            Expanded(
              child: Slider(
                value: _strokeWidth,
                min: 1.0, max: 8.0, divisions: 7,
                label: _strokeWidth.round().toString(),
                onChanged: (v) => setState(() => _strokeWidth = v),
              ),
            ),
          ]),
        ),
        // Signature canvas
        Expanded(
          child: RepaintBoundary(
            key: _canvasKey,
            child: Container(
              color: Colors.white,
              child: GestureDetector(
                onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
                onPanEnd: (_) => setState(() => _strokes.last.add(null)),
                child: CustomPaint(
                  painter: _SignaturePainter(_strokes, _inkColor, _strokeWidth),
                  child: Container(),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Draw your signature, then tap Place to position it on the PDF.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      ]),
    );
  }

  Future<void> _onPlace() async {
    setState(() => _capturing = true);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        NotificationService.showSnackbar(text: 'Could not capture signature', color: Colors.red);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      if (!mounted) return;
      // Navigate to PlaceImageView — user drags and sizes the signature on the PDF page
      GoRouter.of(context).pushNamed(
        AppRoutes.placeImageRoute.name,
        extra: {
          'file': widget.file,
          'imageBytes': byteData.buffer.asUint8List(),
          'title': 'Place Signature',
        },
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
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
      final path = Path();
      bool penDown = false;
      for (final pt in stroke) {
        if (pt == null) {
          penDown = false;
        } else if (!penDown) {
          path.moveTo(pt.dx, pt.dy);
          penDown = true;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
