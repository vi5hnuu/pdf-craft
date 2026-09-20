/// The annotation model for the Annotate tool.
///
/// Two things distinguish this from the private `_DrawObj` hierarchy it replaces, and both are
/// load-bearing:
///
/// 1. **Geometry is in page fractions, origin top-left** — never in canvas pixels. The old model
///    stored raw on-screen `Offset`s, which tied every mark to the size of the phone's canvas at
///    the moment it was drawn. That is why zooming slid the marks off the page, why the exported
///    resolution was capped by the screen, and why the only thing that could be sent to the server
///    was a screenshot. Fractions are also exactly what the backend's `Placement` and
///    [PlaceImageView] already speak, so nothing has to translate.
/// 2. **Every mark has an id and is mutable** — which is what makes selecting, moving, resizing,
///    restyling and deleting one possible at all. Previously a mark could only be undone.
///
/// Mirrors `EditorField` in the form editor, which solved the same problem.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// What a mark is. The wire name is what the backend maps to a PDFBox annotation class.
enum AnnotationKind {
  ink('ink'),
  highlight('highlight'),
  rect('square'),
  ellipse('circle'),
  line('line'),
  arrow('line'),
  text('free_text'),
  sticky('note'),
  /// Raster. Sent through the existing stamp endpoint, not as a PDF annotation — a bitmap has no
  /// meaningful markup-annotation equivalent.
  image('image');

  const AnnotationKind(this.wire);
  final String wire;
}

int _seq = 0;
String _nextId() => 'a${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

/// `#RRGGBB`, which is what the backend's colour parsing expects. Alpha travels separately as
/// `opacity`, because a PDF annotation carries its transparency in `/CA`, not in the colour.
String _hex(Color c) {
  final v = c.toARGB32() & 0x00FFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

sealed class Annotation {
  Annotation({String? id, required this.page, required this.color, this.opacity = 1.0})
      : id = id ?? _nextId();

  final String id;

  /// 0-indexed.
  int page;
  Color color;

  /// 0–1. Sent as the annotation's `/CA`.
  double opacity;

  AnnotationKind get kind;

  /// The mark's extent in page fractions. Setting it moves/resizes the mark, which is how the
  /// drag and resize handles act on every kind uniformly.
  Rect get bounds;
  set bounds(Rect value);

  /// True when resizing should keep the mark's aspect ratio (nothing does today, but a future
  /// stamp would).
  bool get lockAspect => false;

  /// Whether this one is sent to `/annotate-pdf`. Images go through the stamp endpoint instead.
  bool get isPdfAnnotation => kind != AnnotationKind.image;

  Map<String, dynamic> toWire();

  /// A value copy that keeps the same [id].
  ///
  /// Undo and redo snapshot every mark, and a snapshot is the *same* mark at an earlier moment —
  /// so it has to keep its identity. Minting a fresh id here broke two things at once: the
  /// current selection stopped matching after an undo, and an inserted image lost its entry in
  /// the decoded-image cache, which is keyed by id, so it came back as an empty box.
  Annotation copy();

  /// A copy that is a genuinely new mark. Only [duplicate] mints a new id.
  Annotation duplicate();

  /// Shared wire fields.
  Map<String, dynamic> _base() => {
        'type': kind.wire,
        'page': page,
        'color': _hex(color),
        'opacity': opacity,
      };
}

/// A freehand stroke: the pen, and the highlighter.
///
/// Both are points plus a width; the difference is only which PDF annotation they become. The
/// highlighter is *not* drawn as a translucent stroke on the server — it becomes a real
/// `/Highlight`, which multiplies over the text underneath instead of greying it out, and which
/// therefore does not darken where two strokes overlap.
class InkAnnotation extends Annotation {
  InkAnnotation({
    super.id,
    required super.page,
    required super.color,
    required this.points,
    required this.strokeWidth,
    this.highlighter = false,
    super.opacity,
  });

  /// Page fractions.
  List<Offset> points;

  /// As a fraction of the page's *shorter* side, so a stroke keeps its visual weight whatever the
  /// page size. Storing it in pixels is what made marks look right on the phone and wrong on the
  /// page.
  double strokeWidth;

  final bool highlighter;

  @override
  AnnotationKind get kind => highlighter ? AnnotationKind.highlight : AnnotationKind.ink;

  @override
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Moving or resizing a stroke maps every point through the same transform, so the shape is
  /// preserved rather than re-fitted to the box.
  @override
  set bounds(Rect value) {
    final old = bounds;
    if (old.width <= 0 && old.height <= 0) return;
    final sx = old.width == 0 ? 1.0 : value.width / old.width;
    final sy = old.height == 0 ? 1.0 : value.height / old.height;
    points = [
      for (final p in points)
        Offset(value.left + (p.dx - old.left) * sx, value.top + (p.dy - old.top) * sy)
    ];
  }

  @override
  Map<String, dynamic> toWire() => {
        ..._base(),
        'stroke_width': strokeWidth,
        'points': [
          for (final p in points) [p.dx, p.dy]
        ],
      };

  @override
  InkAnnotation copy() => InkAnnotation(
        id: id,
        page: page,
        color: color,
        points: List<Offset>.from(points),
        strokeWidth: strokeWidth,
        highlighter: highlighter,
        opacity: opacity,
      );

  @override
  InkAnnotation duplicate() => InkAnnotation(
        page: page,
        color: color,
        points: List<Offset>.from(points),
        strokeWidth: strokeWidth,
        highlighter: highlighter,
        opacity: opacity,
      );
}

/// A rectangle or an ellipse.
class ShapeAnnotation extends Annotation {
  ShapeAnnotation({
    super.id,
    required super.page,
    required super.color,
    required Rect bounds,
    required this.strokeWidth,
    required this.ellipse,
    this.fillColor,
    super.opacity,
  }) : _bounds = bounds;

  Rect _bounds;
  double strokeWidth;
  final bool ellipse;
  Color? fillColor;

  @override
  AnnotationKind get kind => ellipse ? AnnotationKind.ellipse : AnnotationKind.rect;

  @override
  Rect get bounds => _bounds;

  @override
  set bounds(Rect value) => _bounds = value;

  @override
  Map<String, dynamic> toWire() => {
        ..._base(),
        'rect': [_bounds.left, _bounds.top, _bounds.width, _bounds.height],
        'stroke_width': strokeWidth,
        if (fillColor != null) 'fill_color': _hex(fillColor!),
      };

  @override
  ShapeAnnotation copy() => ShapeAnnotation(
        id: id,
        page: page,
        color: color,
        bounds: _bounds,
        strokeWidth: strokeWidth,
        ellipse: ellipse,
        fillColor: fillColor,
        opacity: opacity,
      );

  @override
  ShapeAnnotation duplicate() => ShapeAnnotation(
        page: page,
        color: color,
        bounds: _bounds,
        strokeWidth: strokeWidth,
        ellipse: ellipse,
        fillColor: fillColor,
        opacity: opacity,
      );
}

/// A straight line, optionally with an arrowhead at the far end.
class LineAnnotation extends Annotation {
  LineAnnotation({
    super.id,
    required super.page,
    required super.color,
    required this.from,
    required this.to,
    required this.strokeWidth,
    this.arrow = false,
    super.opacity,
  });

  Offset from;
  Offset to;
  double strokeWidth;
  final bool arrow;

  @override
  AnnotationKind get kind => arrow ? AnnotationKind.arrow : AnnotationKind.line;

  @override
  Rect get bounds => Rect.fromPoints(from, to);

  /// Keeps which end is which, so an arrow resized by its handles still points the way it did.
  @override
  set bounds(Rect value) {
    final old = bounds;
    if (old.width == 0 && old.height == 0) return;
    Offset map(Offset p) => Offset(
          old.width == 0 ? value.left : value.left + (p.dx - old.left) / old.width * value.width,
          old.height == 0 ? value.top : value.top + (p.dy - old.top) / old.height * value.height,
        );
    from = map(from);
    to = map(to);
  }

  @override
  Map<String, dynamic> toWire() => {
        ..._base(),
        'from': [from.dx, from.dy],
        'to': [to.dx, to.dy],
        'stroke_width': strokeWidth,
        'arrow': arrow,
      };

  @override
  LineAnnotation copy() => LineAnnotation(
        id: id,
        page: page,
        color: color,
        from: from,
        to: to,
        strokeWidth: strokeWidth,
        arrow: arrow,
        opacity: opacity,
      );

  @override
  LineAnnotation duplicate() => LineAnnotation(
        page: page,
        color: color,
        from: from,
        to: to,
        strokeWidth: strokeWidth,
        arrow: arrow,
        opacity: opacity,
      );
}

/// Free text drawn directly on the page.
class TextAnnotation extends Annotation {
  TextAnnotation({
    super.id,
    required super.page,
    required super.color,
    required Rect bounds,
    required this.text,
    required this.fontSize,
    this.bold = false,
    super.opacity,
  }) : _bounds = bounds;

  Rect _bounds;
  String text;

  /// Fraction of the page height, for the same reason as [InkAnnotation.strokeWidth].
  double fontSize;
  bool bold;

  @override
  AnnotationKind get kind => AnnotationKind.text;

  @override
  Rect get bounds => _bounds;

  @override
  set bounds(Rect value) => _bounds = value;

  @override
  Map<String, dynamic> toWire() => {
        ..._base(),
        'rect': [_bounds.left, _bounds.top, _bounds.width, _bounds.height],
        'text': text,
        'font_size': fontSize,
        'bold': bold,
      };

  @override
  TextAnnotation copy() => TextAnnotation(
        id: id,
        page: page,
        color: color,
        bounds: _bounds,
        text: text,
        fontSize: fontSize,
        bold: bold,
        opacity: opacity,
      );

  @override
  TextAnnotation duplicate() => TextAnnotation(
        page: page,
        color: color,
        bounds: _bounds,
        text: text,
        fontSize: fontSize,
        bold: bold,
        opacity: opacity,
      );
}

/// A sticky note — a real `/Text` annotation, so it collapses to an icon and opens as a comment
/// in any viewer, rather than being a yellow rectangle burnt into the page.
class StickyAnnotation extends Annotation {
  StickyAnnotation({
    super.id,
    required super.page,
    required super.color,
    required Rect bounds,
    required this.text,
    super.opacity,
  }) : _bounds = bounds;

  Rect _bounds;
  String text;

  @override
  AnnotationKind get kind => AnnotationKind.sticky;

  @override
  Rect get bounds => _bounds;

  @override
  set bounds(Rect value) => _bounds = value;

  @override
  Map<String, dynamic> toWire() => {
        ..._base(),
        'rect': [_bounds.left, _bounds.top, _bounds.width, _bounds.height],
        'text': text,
      };

  @override
  StickyAnnotation copy() => StickyAnnotation(
        id: id,
        page: page,
        color: color,
        bounds: _bounds,
        text: text,
        opacity: opacity,
      );

  @override
  StickyAnnotation duplicate() => StickyAnnotation(
        page: page,
        color: color,
        bounds: _bounds,
        text: text,
        opacity: opacity,
      );
}

/// An image or a signature dropped onto the page.
///
/// Stays raster and goes through the stamp endpoint: there is no markup annotation that means
/// "this bitmap", and burning it in is what the user wants from a signature anyway.
class ImageAnnotation extends Annotation {
  ImageAnnotation({
    super.id,
    required super.page,
    required Rect bounds,
    required this.bytes,
    this.isSignature = false,
    super.opacity,
  })  : _bounds = bounds,
        super(color: const Color(0xFF000000));

  Rect _bounds;
  final Uint8List bytes;
  final bool isSignature;

  @override
  AnnotationKind get kind => AnnotationKind.image;

  @override
  bool get lockAspect => true;

  @override
  Rect get bounds => _bounds;

  @override
  set bounds(Rect value) => _bounds = value;

  /// Never sent as JSON — the stamp endpoint takes the bytes as a multipart part.
  @override
  Map<String, dynamic> toWire() => {
        ..._base(),
        'rect': [_bounds.left, _bounds.top, _bounds.width, _bounds.height],
      };

  @override
  ImageAnnotation copy() => ImageAnnotation(
        id: id,
        page: page,
        bounds: _bounds,
        bytes: bytes,
        isSignature: isSignature,
        opacity: opacity,
      );

  @override
  ImageAnnotation duplicate() => ImageAnnotation(
        page: page,
        bounds: _bounds,
        bytes: bytes,
        isSignature: isSignature,
        opacity: opacity,
      );
}
