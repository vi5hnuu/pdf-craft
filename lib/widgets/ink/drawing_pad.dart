/// A reusable freehand drawing surface.
///
/// Shared by the Sign tool, the signature sheet inside Annotate, and anything else that needs
/// "draw with a finger". Each of those had its own copy, and each copy had its own bugs:
///
/// * **Nothing was drawn at all.** The gesture detector wrapped a `CustomPaint` whose child
///   painted nothing, and a `RenderBox` does not hit-test itself by default — so the pointer fell
///   straight through. [HitTestBehavior.opaque] is what makes a blank surface touchable.
/// * **Strokes appeared but never updated.** The painter compared `old.strokes` with `strokes`,
///   which were the *same* list mutated in place, so the comparison was always false and
///   `shouldRepaint` never fired. A revision counter is compared instead — a value that actually
///   changes.
/// * **Lines were angular.** Points were joined with `lineTo`. They go through
///   [buildInkPath] now, like every other stroke in the app.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf_craft/widgets/ink/ink_painting.dart';

/// Drives a [DrawingPad] from outside: undo, redo, clear, and export.
class DrawingPadController extends ChangeNotifier {
  final List<InkStroke> _strokes = [];
  final List<InkStroke> _redo = [];

  /// Bumped on every change. The painter compares this rather than the stroke list, which it
  /// mutates in place and could therefore never see change.
  int _revision = 0;
  int get revision => _revision;

  List<InkStroke> get strokes => List.unmodifiable(_strokes);

  bool get isEmpty => _strokes.every((s) => s.points.isEmpty);
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _touch() {
    _revision++;
    notifyListeners();
  }

  void begin(Offset at, Color color, double width) {
    _redo.clear();
    _strokes.add(InkStroke(points: [at], color: color, width: width));
    _touch();
  }

  void extend(Offset to) {
    if (_strokes.isEmpty) return;
    final points = _strokes.last.points;
    // Thinned as it is drawn: samples a finger cannot distinguish cost render time and, once
    // exported, file size.
    if (points.isNotEmpty && !inkShouldAdd(points.last, to)) return;
    points.add(to);
    _touch();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redo.add(_strokes.removeLast());
    _touch();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _strokes.add(_redo.removeLast());
    _touch();
  }

  void clear() {
    if (_strokes.isEmpty && _redo.isEmpty) return;
    _strokes.clear();
    _redo.clear();
    _touch();
  }

  /// The ink's bounding box, padded by the widest stroke so nothing is clipped.
  Rect? inkBounds() {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    var widest = 0.0;
    for (final s in _strokes) {
      widest = math.max(widest, s.width);
      for (final p in s.points) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    if (minX > maxX) return null;
    final pad = math.max(widest, 1) * 1.5;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  /// Exports the ink as a transparent PNG, cropped to what was actually drawn.
  ///
  /// Cropping is the point: a signature scrawled in the corner of a wide pad, exported whole,
  /// is mostly empty space — so it lands on the page tiny and off-centre.
  Future<Uint8List?> exportPng({double scale = 3.0}) async {
    final bounds = inkBounds();
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);
    for (final s in _strokes) {
      paintInkStroke(canvas, s.points, inkPaint(s.color, s.width));
    }
    final image = await recorder
        .endRecording()
        .toImage((bounds.width * scale).ceil(), (bounds.height * scale).ceil());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

class DrawingPad extends StatelessWidget {
  const DrawingPad({
    super.key,
    required this.controller,
    required this.color,
    required this.width,
    this.guideLine = false,
    this.background = Colors.white,
  });

  final DrawingPadController controller;
  final Color color;
  final double width;

  /// A ruled line to sign on, like a signing pad.
  final bool guideLine;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Stack(children: [
        Positioned.fill(child: ColoredBox(color: background)),
        if (guideLine)
          Positioned(
            left: 16,
            right: 16,
            bottom: 44,
            child: Container(height: 1, color: Colors.black12),
          ),
        Positioned.fill(
          child: GestureDetector(
            // Without this the pad is not touchable at all: a CustomPaint whose child paints
            // nothing does not hit-test itself, so every pointer went straight through it.
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => controller.begin(d.localPosition, color, width),
            onPanUpdate: (d) => controller.extend(d.localPosition),
            child: CustomPaint(
              painter: _PadPainter(controller.strokes, controller.revision),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes, this.revision);

  final List<InkStroke> strokes;

  /// Compared instead of [strokes], which is the same list object each time.
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      paintInkStroke(canvas, s.points, inkPaint(s.color, s.width));
    }
  }

  @override
  bool shouldRepaint(_PadPainter old) => old.revision != revision;
}
