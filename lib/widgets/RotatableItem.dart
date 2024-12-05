import 'package:flutter/material.dart';
import 'dart:math';

class RotatablePageWidget extends StatelessWidget {
  final double originalWidth;
  final double originalHeight;
  final bool maintainAspectRatio;
  final double rotationAngle; // in degrees (0 to 360)
  final Widget child;

  RotatablePageWidget({
    required this.originalWidth,
    required this.originalHeight,
    required this.maintainAspectRatio,
    required this.rotationAngle,
    required this.child,
  }):assert(rotationAngle>=0 && rotationAngle<=360);

  @override
  Widget build(BuildContext context) {
    double width = originalWidth;
    double height = originalHeight;

    if (rotationAngle == 90 || rotationAngle == 270) {
      // When rotated 90 or 270 degrees, width and height are swapped
      if (!maintainAspectRatio) {
        // Only rotate the content, no change in width and height
        width = originalWidth;
        height = originalHeight;
      } else {
        // Maintain aspect ratio, swap width and height
        width = originalHeight;
        height = originalWidth;
      }
    }
    else if (rotationAngle == 180 || rotationAngle == 0) {
      width = originalWidth;
      height = originalHeight;
    } else{
      // For angles between 0 and 90 degrees, calculate the width/height based on rotation
      if (maintainAspectRatio) {
        double aspectRatio = originalWidth / originalHeight;
        width = originalHeight * sin(rotationAngle * pi / 180) + originalWidth * cos(rotationAngle * pi / 180);
        height = width / aspectRatio;
      } else {
        width = originalWidth;
        height = originalHeight;
      }
    }


    return Transform.rotate(
      angle: rotationAngle * pi / 180, // Convert to radians
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey, // Background color for the page
          border: Border.all(color: Colors.black), // Border for the page
        ),
        child: Center(
          child: child,
        ),
      ),
    );
  }
}
