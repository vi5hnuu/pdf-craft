/// Freehand ink: the geometry and the painting, in one place.
///
/// There were three copies of "turn a list of touch points into a stroke" — the annotate canvas,
/// the Sign tool and the signature sheet — and they disagreed. Two joined the points with
/// straight lines, which is what made drawing look angular however carefully you moved your
/// finger; only one smoothed. This is the smoothing one, shared.
library;

import 'dart:ui';

/// A single freehand stroke in whatever coordinate space the caller is using.
class InkStroke {
  InkStroke({required this.points, required this.color, required this.width});

  final List<Offset> points;
  final Color color;
  final double width;

  InkStroke copy() => InkStroke(points: List.of(points), color: color, width: width);
}

/// Points closer together than this add nothing a finger can see, and cost everything
/// downstream — more path segments to render, a bigger PDF, and for a highlighter one
/// `QuadPoints` quad per segment.
const double kInkMinSpacingPx = 1.5;

/// True when [point] is far enough from [last] to be worth recording.
bool inkShouldAdd(Offset last, Offset point, {double minSpacing = kInkMinSpacingPx}) =>
    (point - last).distance >= minSpacing;

/// A smooth path through [points].
///
/// Each segment is a quadratic Bézier whose control point is the sampled point and whose
/// endpoint is the midpoint of the next pair. That makes every sampled point a tangent rather
/// than a corner, so the curve passes *near* the samples instead of turning sharply at each one
/// — which is exactly the difference between a hand-drawn line and a polyline.
///
/// Fewer than three points cannot be smoothed; the caller draws those as a dot or a short line.
Path buildInkPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;

  path.moveTo(points.first.dx, points.first.dy);
  if (points.length < 3) {
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset(
      (points[i].dx + points[i + 1].dx) / 2,
      (points[i].dy + points[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  // The loop stops one short, so the tail is drawn straight to the last sample.
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

/// Draws one stroke. A single point becomes a dot, which is what tapping a pen down should do.
void paintInkStroke(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.isEmpty) return;
  if (points.length == 1) {
    canvas.drawCircle(points.first, paint.strokeWidth / 2, Paint()..color = paint.color);
    return;
  }
  canvas.drawPath(buildInkPath(points), paint);
}

/// The paint a freehand stroke is drawn with.
Paint inkPaint(Color color, double width) => Paint()
  ..color = color
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..style = PaintingStyle.stroke;
