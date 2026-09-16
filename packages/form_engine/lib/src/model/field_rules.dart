/// Presentation and input rules a field can carry.
library;

/// How text sits inside its box. Maps to the PDF `/Q` quadding entry.
enum TextAlignment {
  left(0),
  center(1),
  right(2);

  final int quadding;
  const TextAlignment(this.quadding);

  static TextAlignment fromWire(String? name) =>
      TextAlignment.values.firstWhere((a) => a.name == name, orElse: () => TextAlignment.left);
}

/// The kind of content a text field expects.
///
/// Drives three separate things: the keyboard the filler gets, the validation the app runs,
/// and the format/keystroke action written into the PDF for desktop readers. It is not a
/// separate PDF field type — every one of these is a text field in AcroForm terms.
enum TextFormat {
  none,
  number,
  email,
  phone,
  date;

  static TextFormat fromWire(String? name) =>
      TextFormat.values.firstWhere((f) => f.name == name, orElse: () => TextFormat.none);
}

/// Input rules for one field.
///
/// Evaluated by the app rather than relying on the PDF's own JavaScript, which most mobile
/// readers ignore — a form that only validated through embedded script would appear to accept
/// anything on a phone.
class FieldValidation {
  final String? pattern; // regular expression the value must match
  final int? minLength;
  final int? maxLength;
  final num? min; // numeric bounds, only meaningful for TextFormat.number
  final num? max;

  const FieldValidation({this.pattern, this.minLength, this.maxLength, this.min, this.max});

  bool get isEmpty =>
      pattern == null && minLength == null && maxLength == null && min == null && max == null;

  Map<String, Object?> toJson() => {
        if (pattern != null) 'pattern': pattern,
        if (minLength != null) 'min_length': minLength,
        if (maxLength != null) 'max_length': maxLength,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };

  static FieldValidation fromJson(Map<String, Object?> json) => FieldValidation(
        pattern: json['pattern'] as String?,
        minLength: (json['min_length'] as num?)?.toInt(),
        maxLength: (json['max_length'] as num?)?.toInt(),
        min: json['min'] as num?,
        max: json['max'] as num?,
      );
}
