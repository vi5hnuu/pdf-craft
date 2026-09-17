import 'package:flutter/material.dart';

// Displays a child widget with a rotation applied for preview purposes.
// Uses RotatedBox (layout-aware) + FittedBox so the rotated content always
// fits within the originalWidth × originalHeight bounding box without overflow.
class RotatablePageWidget extends StatelessWidget {
  final double originalWidth;
  final double originalHeight;
  final bool maintainAspectRatio; // kept for API compatibility, not used in rendering
  final double rotationAngle; // degrees; must be 0, 90, 180 or 270
  final Widget child;

  const RotatablePageWidget({
    super.key,
    required this.originalWidth,
    required this.originalHeight,
    required this.maintainAspectRatio,
    required this.rotationAngle,
    required this.child,
  }) : assert(rotationAngle >= 0);

  @override
  Widget build(BuildContext context) {
    final quarterTurns = (rotationAngle / 90).round() % 4;

    return SizedBox(
      width: originalWidth,
      height: originalHeight,
      child: FittedBox(
        fit: BoxFit.contain,
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: SizedBox(
            width: originalWidth,
            height: originalHeight,
            child: child,
          ),
        ),
      ),
    );
  }
}
