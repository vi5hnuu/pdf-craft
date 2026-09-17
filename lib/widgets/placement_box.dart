/// A draggable, resizable box over a rendered page, in fractional page coordinates.
///
/// Several tools ask "where on the page?" and the answer has to survive being rendered at a
/// different size, so the box is stored as fractions (0..1) rather than pixels — the same shape
/// the backend's `x_frac`/`y_frac`/`width_frac`/`height_frac` already expect.
///
/// Built for Stamp PDF, which sent no placement at all because the screen had no way to express
/// one. Kept general so the next tool that needs a box does not invent another.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class PlacementBox extends StatelessWidget {
  /// The box, as fractions of the page, origin top-left.
  final Rect rect;

  /// The rendered page's size on screen.
  final Size canvas;

  /// The page's size in PDF points, used only for the readout.
  final Size pagePoints;

  final ValueChanged<Rect> onChanged;

  /// Width and height stay in this ratio (width / height) when resizing. Null lets them move
  /// independently.
  final double? aspect;

  /// Drawn inside the box — the artwork being placed, when there is something to show.
  final Widget? child;

  const PlacementBox({
    super.key,
    required this.rect,
    required this.canvas,
    required this.pagePoints,
    required this.onChanged,
    this.aspect,
    this.child,
  });

  /// Smallest the box may get, as a fraction — small enough for a logo, large enough to keep
  /// the resize handle reachable.
  static const double _minFraction = 0.03;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final left = rect.left * canvas.width;
    final top = rect.top * canvas.height;
    final width = rect.width * canvas.width;
    final height = rect.height * canvas.height;

    void move(Offset delta) {
      final l = (rect.left + delta.dx / canvas.width).clamp(0.0, 1 - rect.width);
      final t = (rect.top + delta.dy / canvas.height).clamp(0.0, 1 - rect.height);
      onChanged(Rect.fromLTWH(l, t, rect.width, rect.height));
    }

    void resize(Offset delta) {
      var w = (rect.width + delta.dx / canvas.width).clamp(_minFraction, 1 - rect.left);
      var h = (rect.height + delta.dy / canvas.height).clamp(_minFraction, 1 - rect.top);
      if (aspect != null) {
        // Follow whichever axis the finger moved further on screen, then derive the other, so
        // the artwork is never stretched out of shape.
        final drivenByWidth = delta.dx.abs() >= delta.dy.abs();
        if (drivenByWidth) {
          h = (w * canvas.width / aspect! / canvas.height).clamp(_minFraction, 1 - rect.top);
          w = h * canvas.height * aspect! / canvas.width;
        } else {
          w = (h * canvas.height * aspect! / canvas.width).clamp(_minFraction, 1 - rect.left);
          h = w * canvas.width / aspect! / canvas.height;
        }
      }
      onChanged(Rect.fromLTWH(rect.left, rect.top, w, h));
    }

    final widthPt = rect.width * pagePoints.width;
    final heightPt = rect.height * pagePoints.height;

    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Semantics(
          label: L10n.of(context).placementBoxLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => move(d.delta),
            child: Container(
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                border: Border.all(color: primary, width: 1.5),
              ),
              child: child == null
                  ? null
                  : Padding(padding: const EdgeInsets.all(2), child: child),
            ),
          ),
        ),
      ),
      // Size readout in points, above the box — or below it when the box is near the top.
      Positioned(
        left: left,
        top: top > 26 ? top - 22 : top + height + 6,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(AppRadius.surface),
            ),
            child: Text(
              '${widthPt.toStringAsFixed(0)} x ${heightPt.toStringAsFixed(0)} pt',
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      // Resize handle, bottom-right. The dot stays small so it does not cover the artwork, but
      // the touch target is padded out to the 48dp minimum.
      Positioned(
        left: math.max(0, left + width - 24),
        top: math.max(0, top + height - 24),
        child: Semantics(
          button: true,
          label: L10n.of(context).placementResizeLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => resize(d.delta),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
