/// Geometry primitives for the form model.
///
/// These exist instead of `dart:ui`'s `Rect`/`Size` so the engine stays pure
/// Dart: the core can be unit-tested with `dart test` in milliseconds and could
/// later back a web form builder that never loads Flutter.
library;

/// A size expressed as a fraction of the page (0..1 on each axis).
///
/// Fractions rather than points because a field must keep its place when the
/// page is re-rendered at a different zoom or pixel size.
class FractionalSize {
  final double width;
  final double height;

  const FractionalSize(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      other is FractionalSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'FractionalSize($width, $height)';
}

/// A size in PDF points, for the field types whose size is absolute rather than relative to
/// the page — a checkbox is 12pt on A4 and 12pt on Letter.
class PointSize {
  final double width;
  final double height;

  const PointSize(this.width, this.height);

  /// This size as a fraction of a page [pageWidth] x [pageHeight] points.
  FractionalSize toFraction(double pageWidth, double pageHeight) =>
      FractionalSize(width / pageWidth, height / pageHeight);

  @override
  bool operator ==(Object other) =>
      other is PointSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'PointSize($width, $height)';
}

/// A rectangle in fractional page coordinates, origin at the page's top-left.
///
/// The backend expects PDF points with a top-left origin and flips Y itself, so
/// multiplying these by the page size in points is all the conversion needed.
class FractionalRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const FractionalRect(this.left, this.top, this.width, this.height);

  const FractionalRect.fromLTWH(this.left, this.top, this.width, this.height);

  double get right => left + width;
  double get bottom => top + height;

  FractionalRect copyWith({double? left, double? top, double? width, double? height}) =>
      FractionalRect(
        left ?? this.left,
        top ?? this.top,
        width ?? this.width,
        height ?? this.height,
      );

  /// Clamps the rect inside the page, preserving its size where possible.
  ///
  /// A field dragged past the edge would otherwise be written outside the page
  /// box, where most readers simply do not draw it.
  FractionalRect clampedToPage() {
    final w = width.clamp(0.0, 1.0);
    final h = height.clamp(0.0, 1.0);
    return FractionalRect(
      left.clamp(0.0, 1.0 - w),
      top.clamp(0.0, 1.0 - h),
      w,
      h,
    );
  }

  Map<String, Object?> toJson() => {'left': left, 'top': top, 'width': width, 'height': height};

  static FractionalRect fromJson(Map<String, Object?> json) => FractionalRect(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is FractionalRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'FractionalRect($left, $top, $width, $height)';
}

/// A page size in PDF points, used only to convert fractions to points.
class PageSizePoints {
  final double width;
  final double height;

  const PageSizePoints(this.width, this.height);
}
