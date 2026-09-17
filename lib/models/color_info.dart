import 'dart:ui';

/// A colour in the 0–255 channels the API expects.
///
/// Flutter's [Color] channels became 0–1 doubles, so every screen that sent a colour was doing
/// the same conversion by hand through the deprecated int accessors. [ColorInfo.fromColor] is
/// the one place that conversion lives now.
class ColorInfo {
  final int r;
  final int g;
  final int b;
  final int? a;

  ColorInfo({required this.r, required this.g, required this.b, required this.a});

  /// Converts a Flutter [Color], whose channels are 0–1 doubles, to 0–255 integers.
  factory ColorInfo.fromColor(Color color) => ColorInfo(
        r: _channel(color.r),
        g: _channel(color.g),
        b: _channel(color.b),
        a: _channel(color.a),
      );

  static int _channel(double value) => (value * 255).round().clamp(0, 255);

  Map<String, dynamic> toJson() {
    return {
      "r": r,
      "g": g,
      "b": b,
      "a": a,
    };
  }
}
