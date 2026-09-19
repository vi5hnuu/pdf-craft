/// Draws the annotation layer.
///
/// Every mark is stored in page fractions, so this is the one place that turns a fraction into a
/// pixel — `size` is whatever the page is currently rendered at. That is what lets the same marks
/// survive a rotation, a zoom, or a different phone without moving relative to the page.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf_craft/pages/annotate/annotation.dart';

class AnnotationPainter extends CustomPainter {
  AnnotationPainter({
    required this.annotations,
    required this.selectedId,
    this.preview,
    this.imageCache = const {},
  });

  final List<Annotation> annotations;
  final String? selectedId;

  /// The mark being dragged out right now, drawn but not yet committed.
  final Annotation? preview;

  /// Decoded images, keyed by annotation id. Decoding is async, so the screen decodes once and
  /// hands the results in; a painter cannot await.
  final Map<String, ui.Image> imageCache;

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in annotations) {
      _paint(canvas, size, a);
    }
    final p = preview;
    if (p != null) _paint(canvas, size, p, ghost: true);

    // The selection outline goes on top of everything, so a mark under another one is still
    // visibly the selected one.
    final sel = selectedId;
    if (sel != null) {
      for (final a in annotations) {
        if (a.id != sel) continue;
        final r = _toPx(a.bounds, size).inflate(3);
        canvas.drawRect(
          r,
          Paint()
            ..color = const Color(0xFF2962FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  Rect _toPx(Rect frac, Size size) => Rect.fromLTWH(
        frac.left * size.width,
        frac.top * size.height,
        frac.width * size.width,
        frac.height * size.height,
      );

  Offset _ptPx(Offset frac, Size size) =>
      Offset(frac.dx * size.width, frac.dy * size.height);

  /// A width stored as a fraction of the page's shorter side, in pixels.
  double _strokePx(double frac, Size size) =>
      math.max(1.0, frac * math.min(size.width, size.height));

  void _paint(Canvas canvas, Size size, Annotation a, {bool ghost = false}) {
    final opacity = (ghost ? a.opacity * 0.6 : a.opacity).clamp(0.0, 1.0);

    switch (a) {
      case InkAnnotation ink:
        if (ink.points.isEmpty) return;
        final paint = Paint()
          ..color = ink.color.withValues(alpha: opacity * (ink.highlighter ? 0.45 : 1.0))
          ..strokeWidth = _strokePx(ink.strokeWidth, size)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          // A highlighter multiplies: the text underneath stays readable and two overlapping
          // strokes do not compound into a darker band. On the produced PDF this is a real
          // /Highlight annotation, which behaves the same way — so what the author sees here is
          // what the file does.
          ..blendMode = ink.highlighter ? BlendMode.multiply : BlendMode.srcOver;

        if (ink.points.length == 1) {
          canvas.drawCircle(_ptPx(ink.points.first, size),
              paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
          return;
        }
        final path = Path();
        final first = _ptPx(ink.points.first, size);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < ink.points.length; i++) {
          final p = _ptPx(ink.points[i], size);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);

      case ShapeAnnotation s:
        final rect = _toPx(s.bounds, size);
        final fill = s.fillColor;
        if (fill != null) {
          final fp = Paint()
            ..color = fill.withValues(alpha: opacity)
            ..style = PaintingStyle.fill;
          s.ellipse ? canvas.drawOval(rect, fp) : canvas.drawRect(rect, fp);
        }
        final sp = Paint()
          ..color = s.color.withValues(alpha: opacity)
          ..strokeWidth = _strokePx(s.strokeWidth, size)
          ..style = PaintingStyle.stroke;
        s.ellipse ? canvas.drawOval(rect, sp) : canvas.drawRect(rect, sp);

      case LineAnnotation l:
        final from = _ptPx(l.from, size);
        final to = _ptPx(l.to, size);
        final w = _strokePx(l.strokeWidth, size);
        final paint = Paint()
          ..color = l.color.withValues(alpha: opacity)
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, paint);
        if (l.arrow) _arrowHead(canvas, from, to, l.color.withValues(alpha: opacity), w);

      case TextAnnotation t:
        final rect = _toPx(t.bounds, size);
        final tp = TextPainter(
          text: TextSpan(
            text: t.text,
            style: TextStyle(
              color: t.color.withValues(alpha: opacity),
              fontSize: math.max(6.0, t.fontSize * size.height),
              fontWeight: t.bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(24.0, rect.width));
        tp.paint(canvas, rect.topLeft);

      case StickyAnnotation s:
        // Drawn as a note icon, because that is what a /Text annotation is in the produced PDF:
        // a marker you tap to read, not a yellow box burnt into the page. Showing a big filled
        // rectangle here would promise something the file does not do.
        final rect = _toPx(s.bounds, size);
        final side = math.min(rect.width, math.max(18.0, rect.height));
        final box = Rect.fromLTWH(rect.left, rect.top, side, side);
        final rr = RRect.fromRectAndRadius(box, const Radius.circular(3));
        canvas.drawRRect(rr, Paint()..color = s.color.withValues(alpha: opacity));
        canvas.drawRRect(
            rr,
            Paint()
              ..color = Colors.black38
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        // Three lines suggesting written text, so it reads as a note at a glance.
        final line = Paint()
          ..color = Colors.black54
          ..strokeWidth = math.max(1.0, side * 0.06);
        for (var i = 1; i <= 3; i++) {
          final y = box.top + side * i / 4;
          canvas.drawLine(
              Offset(box.left + side * 0.2, y), Offset(box.right - side * 0.2, y), line);
        }

      case ImageAnnotation img:
        final rect = _toPx(img.bounds, size);
        final decoded = imageCache[img.id];
        if (decoded == null) {
          // Still decoding: a placeholder, so the author can see where it will land rather than
          // watching nothing happen.
          canvas.drawRect(
              rect,
              Paint()
                ..color = Colors.black26
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1);
          return;
        }
        paintImage(
          canvas: canvas,
          rect: rect,
          image: decoded,
          fit: BoxFit.contain,
          opacity: opacity,
          filterQuality: FilterQuality.medium,
        );
    }
  }

  void _arrowHead(Canvas canvas, Offset from, Offset to, Color color, double width) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final size = math.max(8.0, width * 3.5);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - size * math.cos(angle - 0.45), to.dy - size * math.sin(angle - 0.45))
      ..lineTo(to.dx - size * math.cos(angle + 0.45), to.dy - size * math.sin(angle + 0.45))
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(AnnotationPainter old) =>
      // The old painter returned true unconditionally, repainting the whole overlay every frame
      // of every animation on the screen. These four are the only things it draws from.
      old.annotations != annotations ||
      old.annotations.length != annotations.length ||
      old.selectedId != selectedId ||
      old.preview != preview ||
      old.imageCache.length != imageCache.length;
}
