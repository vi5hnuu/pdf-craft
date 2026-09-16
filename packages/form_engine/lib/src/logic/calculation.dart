/// Computed fields: a field whose value is derived from others.
///
/// The five functions match the ones every PDF reader already implements through
/// `AFSimple_Calculate`, so the same rule can be written into the document for desktop
/// readers while the app computes it itself for the mobile ones that ignore script.
library;

enum CalculationFunction {
  sum,
  average,
  product,
  min,
  max;

  /// Name used by the PDF's own AFSimple_Calculate helper.
  String get acrobatName => switch (this) {
        CalculationFunction.sum => 'SUM',
        CalculationFunction.average => 'AVG',
        CalculationFunction.product => 'PRD',
        CalculationFunction.min => 'MIN',
        CalculationFunction.max => 'MAX',
      };

  static CalculationFunction fromWire(String? name) => CalculationFunction.values
      .firstWhere((f) => f.name == name, orElse: () => CalculationFunction.sum);
}

class Calculation {
  final CalculationFunction function;

  /// Names of the fields feeding the calculation.
  final List<String> fields;

  const Calculation({this.function = CalculationFunction.sum, this.fields = const []});

  bool get isEmpty => fields.isEmpty;

  /// Computes the value, or null when nothing numeric is available.
  ///
  /// Non-numeric and missing entries are skipped rather than treated as zero: a total that
  /// silently counts an empty box as 0 in a PRODUCT would always be 0.
  num? evaluate(Map<String, String> values) {
    final numbers = <num>[];
    for (final name in fields) {
      final parsed = num.tryParse((values[name] ?? '').trim());
      if (parsed != null) numbers.add(parsed);
    }
    if (numbers.isEmpty) return null;
    return switch (function) {
      CalculationFunction.sum => numbers.reduce((a, b) => a + b),
      CalculationFunction.average => numbers.reduce((a, b) => a + b) / numbers.length,
      CalculationFunction.product => numbers.reduce((a, b) => a * b),
      CalculationFunction.min => numbers.reduce((a, b) => a < b ? a : b),
      CalculationFunction.max => numbers.reduce((a, b) => a > b ? a : b),
    };
  }

  Map<String, Object?> toJson() => {'function': function.name, 'fields': fields};

  static Calculation fromJson(Map<String, Object?> json) => Calculation(
        function: CalculationFunction.fromWire(json['function'] as String?),
        fields: (json['fields'] as List?)?.cast<String>().toList() ?? const [],
      );
}
