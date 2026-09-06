import 'package:flutter/material.dart';

/// The app's corner radii, in one place.
///
/// Surfaces used to be rounded at whatever value each screen happened to pick — 2, 3, 4, 6,
/// 7, 8, 9, 10, 12, 14, 16, 20, 24 and 28 were all in use, with 12 as the informal default.
/// That reads as soft and inconsistent rather than like a tool. Everything structural now
/// shares [kRadius]; the exceptions are named so it is obvious they are deliberate.
class AppRadius {
  AppRadius._();

  /// Cards, sheets, inputs, buttons, dialogs — anything with edges.
  static const double surface = 2;

  /// Small inline chips and badges, where a hair more softening reads better at 20px tall.
  static const double chip = 3;

  /// Genuinely pill-shaped elements: the credit balance, filter pills, avatars. Squaring
  /// these looks broken rather than sharp, which is why they are kept round.
  static const double pill = 999;

  static BorderRadius get surfaceRadius => BorderRadius.circular(surface);
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}
