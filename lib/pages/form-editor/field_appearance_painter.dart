/// Draws a form field exactly as the produced PDF will draw it.
///
/// The editor used to render all eleven field types as one translucent rounded rectangle with a
/// small type icon in the corner. The PDF looks nothing like that, so an author could not tell
/// a checkbox from a text box by looking, and — the case this was written for — could not size a
/// checkbox to sit on top of a printed box on a bank form, because the thing on screen was not
/// the thing that would be printed.
///
/// Every number here is copied from the backend's own drawing code
/// (`PdfTools.buildToggleStream` and `PdfTools.styleDataEntryWidget`). If that changes, this must
/// change with it — the whole point is that the two agree.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdf_craft/pages/form-editor/form_field_type.dart';

/// Colours the backend writes into the widget's appearance characteristics (`/MK`).
class _PdfColors {
  /// `mk.setBorderColour(0.45, 0.45, 0.45)` — mid grey, visible on white paper.
  static const border = Color(0xFF737373);

  /// `mk.setBackground(0.96, 0.96, 0.96)` — very light grey.
  static const background = Color(0xFFF5F5F5);

  /// Toggles set no `/MK` colours, so they draw in the content stream's default: black.
  static const toggle = Color(0xFF000000);
}

class FieldAppearancePainter extends CustomPainter {
  final FieldType type;

  /// Whether a checkbox/radio shows its "on" glyph. Mirrors `/AS`.
  final bool checked;

  /// Display pixels per PDF point, so a 1pt border is drawn one point wide rather than one
  /// logical pixel wide. Without this the preview lies about line weight at every zoom level.
  final double pxPerPoint;

  const FieldAppearancePainter({
    required this.type,
    required this.checked,
    required this.pxPerPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case FieldType.checkbox:
        _paintCheckbox(canvas, size);
      case FieldType.radio:
        _paintRadio(canvas, size);
      default:
        _paintDataEntry(canvas, size);
    }
  }

  /// `styleDataEntryWidget`: a 1pt grey outline over a very light grey fill, square corners.
  void _paintDataEntry(Canvas canvas, Size size) {
    final width = _lineWidth(1);
    // Stroked rects straddle the path, so inset by half the line width to keep the whole
    // stroke inside the widget's rectangle — which is what a reader does.
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _PdfColors.background);
    canvas.drawRect(
      rect.deflate(width / 2),
      Paint()
        ..color = _PdfColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  /// `buildToggleStream(radio: false)`: `addRect(0.75, 0.75, w - 1.5, h - 1.5)` stroked at 1pt,
  /// plus a two-segment tick when on.
  void _paintCheckbox(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _PdfColors.toggle
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth(1);

    canvas.drawRect(
      Rect.fromLTWH(_pt(0.75), _pt(0.75), size.width - _pt(1.5), size.height - _pt(1.5)),
      stroke,
    );
    if (!checked) return;

    final side = math.min(size.width, size.height);
    final cx = size.width / 2, cy = size.height / 2;
    // The backend's tick, with y mirrored: PDF's origin is bottom-left, Flutter's is top-left.
    final tick = Path()
      ..moveTo(cx - side * 0.24, cy - side * 0.02)
      ..lineTo(cx - side * 0.06, cy + side * 0.17)
      ..lineTo(cx + side * 0.26, cy - side * 0.21);
    canvas.drawPath(
      tick,
      Paint()
        ..color = _PdfColors.toggle
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(_pt(0.8), side * 0.12)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// `buildToggleStream(radio: true)`: a ring of radius `min(w, h) / 2 - 0.75` stroked at 1pt,
  /// with a filled dot of radius `0.22 * side` when on.
  void _paintRadio(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final centre = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      centre,
      math.max(0, side / 2 - _pt(0.75)),
      Paint()
        ..color = _PdfColors.toggle
        ..style = PaintingStyle.stroke
        ..strokeWidth = _lineWidth(1),
    );
    if (!checked) return;
    canvas.drawCircle(centre, side * 0.22, Paint()..color = _PdfColors.toggle);
  }

  double _pt(double points) => points * pxPerPoint;

  /// A hairline still has to be visible when the page is zoomed out, so a sub-pixel line is
  /// clamped rather than disappearing — the shape stays honest even if the weight cannot.
  double _lineWidth(double points) => math.max(0.6, _pt(points));

  @override
  bool shouldRepaint(FieldAppearancePainter old) =>
      old.type != type || old.checked != checked || old.pxPerPoint != pxPerPoint;
}
