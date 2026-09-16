/// Show/hide rules, modelled on the "conditional parent" idea that document-signing products
/// settled on: a field appears only once another field holds a particular value.
library;

enum ConditionOperator {
  equals,
  notEquals,
  contains,
  isEmpty,
  isNotEmpty,
  greaterThan,
  lessThan;

  static ConditionOperator fromWire(String? name) => ConditionOperator.values
      .firstWhere((o) => o.name == name, orElse: () => ConditionOperator.equals);
}

/// "Show this field when [parentField] [operator] [value]".
class VisibilityCondition {
  /// Name of the field this one watches. Names, not ids, because that is what the PDF
  /// carries and what a calculation would reference too.
  final String parentField;
  final ConditionOperator operator;
  final String value;

  const VisibilityCondition({
    required this.parentField,
    this.operator = ConditionOperator.equals,
    this.value = '',
  });

  /// Whether the dependent field should be visible for the given form values.
  ///
  /// An unknown parent counts as empty rather than as a failure: a half-built form should
  /// still be previewable.
  bool isSatisfiedBy(Map<String, String> values) {
    final actual = values[parentField] ?? '';
    switch (operator) {
      case ConditionOperator.equals:
        return actual == value;
      case ConditionOperator.notEquals:
        return actual != value;
      case ConditionOperator.contains:
        return actual.toLowerCase().contains(value.toLowerCase());
      case ConditionOperator.isEmpty:
        return actual.trim().isEmpty;
      case ConditionOperator.isNotEmpty:
        return actual.trim().isNotEmpty;
      case ConditionOperator.greaterThan:
        return _asNumber(actual) > _asNumber(value);
      case ConditionOperator.lessThan:
        return _asNumber(actual) < _asNumber(value);
    }
  }

  static double _asNumber(String raw) => double.tryParse(raw.trim()) ?? 0;

  Map<String, Object?> toJson() => {
        'parent_field': parentField,
        'operator': operator.name,
        'value': value,
      };

  static VisibilityCondition fromJson(Map<String, Object?> json) => VisibilityCondition(
        parentField: json['parent_field'] as String? ?? '',
        operator: ConditionOperator.fromWire(json['operator'] as String?),
        value: json['value'] as String? ?? '',
      );
}
