import '../model/field_ref.dart';
import '../model/field_rules.dart';
import '../model/form_field.dart';
import '../model/form_schema.dart';

/// A structural problem with the form's own wiring.
class SchemaIssue {
  /// Id of the field carrying the broken rule.
  final String fieldId;
  final SchemaProblem problem;

  /// What it pointed at: a missing field id, or the clashing name.
  final String target;

  const SchemaIssue(this.fieldId, this.problem, this.target);

  @override
  String toString() => '$fieldId: ${problem.name} -> $target';
}

enum SchemaProblem { danglingCondition, danglingCalculation, selfReference, duplicateName }

/// One field's problem with the value it currently holds.
class ValidationIssue {
  /// Id of the offending field.
  final String fieldId;
  final ValidationProblem problem;

  /// The bound that was broken, for building a message ("at most 10 characters").
  final Object? limit;

  const ValidationIssue(this.fieldId, this.problem, [this.limit]);

  @override
  String toString() => '$fieldId: ${problem.name}${limit == null ? '' : ' ($limit)'}';
}

enum ValidationProblem { required, pattern, tooShort, tooLong, belowMinimum, aboveMaximum, notANumber, notAnEmail }

/// Evaluates a form's rules against a set of values.
///
/// This is the authority for conditional visibility, calculated values and validation —
/// deliberately *not* the PDF's embedded JavaScript, which mobile readers largely ignore. The
/// same rules are still written into the document for desktop readers, but nothing the user
/// sees depends on them running.
class FormRuntime {
  final FormSchema schema;

  const FormRuntime(this.schema);

  /// Fields currently visible for [values], which is keyed by field **id**.
  ///
  /// A field whose condition points at a field that no longer exists stays visible: hiding it
  /// would make part of the form unreachable because of a dangling rule. [integrityIssues]
  /// reports those separately so the editor can show them.
  List<FormFieldModel> visibleFields(Map<String, String> values) {
    final ids = schema.fields.map((f) => f.id).toSet();
    return schema.fields.where((f) {
      final condition = f.condition;
      if (condition == null) return true;
      if (!ids.contains(condition.parent.id)) return true;
      return condition.isSatisfiedBy(values);
    }).toList(growable: false);
  }

  /// Structural problems with the form itself, as opposed to the values in it.
  ///
  /// Rules reference ids, so a reference can only dangle if the target was deleted — which is
  /// worth telling the author about rather than silently ignoring at fill time.
  List<SchemaIssue> integrityIssues() {
    final ids = schema.fields.map((f) => f.id).toSet();
    final issues = <SchemaIssue>[];
    final seenNames = <String, String>{}; // name -> first id using it

    for (final field in schema.fields) {
      final condition = field.condition;
      if (condition != null && !ids.contains(condition.parent.id)) {
        issues.add(SchemaIssue(field.id, SchemaProblem.danglingCondition, condition.parent.id));
      }
      for (final ref in field.calculation?.fields ?? const <FieldRef>[]) {
        if (!ids.contains(ref.id)) {
          issues.add(SchemaIssue(field.id, SchemaProblem.danglingCalculation, ref.id));
        }
      }
      if (field.calculation?.fields.any((r) => r.id == field.id) ?? false) {
        issues.add(SchemaIssue(field.id, SchemaProblem.selfReference, field.id));
      }
      // Two fields sharing a name collapse into one field in the PDF, so the second one's
      // value silently overwrites the first.
      final clash = seenNames[field.name];
      if (field.name.isNotEmpty && clash != null) {
        issues.add(SchemaIssue(field.id, SchemaProblem.duplicateName, field.name));
      } else if (field.name.isNotEmpty) {
        seenNames[field.name] = field.id;
      }
    }
    return issues;
  }

  /// Applies every calculation, returning a new value map.
  ///
  /// Runs repeatedly so a calculation that feeds another settles, and stops after a bounded
  /// number of passes so a circular reference cannot hang the UI.
  Map<String, String> applyCalculations(Map<String, String> values) {
    final result = Map<String, String>.from(values);
    const maxPasses = 5;
    for (var pass = 0; pass < maxPasses; pass++) {
      var changed = false;
      for (final field in schema.fields) {
        final calc = field.calculation;
        if (calc == null || calc.isEmpty) continue;
        final computed = calc.evaluate(result);
        if (computed == null) continue;
        final text = _format(computed);
        if (result[field.id] != text) {
          result[field.id] = text;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return result;
  }

  /// Trims a computed number: whole values lose the trailing `.0`, others keep two decimals,
  /// which is what a total on a form is expected to look like.
  static String _format(num value) {
    if (value is int || value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  /// Every rule broken by [values]. Empty means the form is ready to submit.
  ///
  /// Hidden fields are skipped — requiring something the filler cannot see is a dead end.
  List<ValidationIssue> validate(Map<String, String> values) {
    final issues = <ValidationIssue>[];
    for (final field in visibleFields(values)) {
      final raw = (values[field.id] ?? '').trim();
      final rules = field.validation;

      if (field.required && raw.isEmpty) {
        issues.add(ValidationIssue(field.id, ValidationProblem.required));
        continue; // one problem per field is enough to act on
      }
      if (raw.isEmpty) continue; // optional and untouched

      if (rules.minLength != null && raw.length < rules.minLength!) {
        issues.add(ValidationIssue(field.id, ValidationProblem.tooShort, rules.minLength));
        continue;
      }
      final cap = rules.maxLength ?? field.maxLength;
      if (cap != null && raw.length > cap) {
        issues.add(ValidationIssue(field.id, ValidationProblem.tooLong, cap));
        continue;
      }
      if (rules.pattern != null && rules.pattern!.isNotEmpty) {
        // A malformed rule must not take the form down with it.
        final regex = RegExp(rules.pattern!);
        if (!regex.hasMatch(raw)) {
          issues.add(ValidationIssue(field.id, ValidationProblem.pattern));
          continue;
        }
      }
      if (field.format == TextFormat.number) {
        final parsed = num.tryParse(raw);
        if (parsed == null) {
          issues.add(ValidationIssue(field.id, ValidationProblem.notANumber));
          continue;
        }
        if (rules.min != null && parsed < rules.min!) {
          issues.add(ValidationIssue(field.id, ValidationProblem.belowMinimum, rules.min));
          continue;
        }
        if (rules.max != null && parsed > rules.max!) {
          issues.add(ValidationIssue(field.id, ValidationProblem.aboveMaximum, rules.max));
          continue;
        }
      }
      if (field.format == TextFormat.email && !_looksLikeEmail(raw)) {
        issues.add(ValidationIssue(field.id, ValidationProblem.notAnEmail));
      }
    }
    return issues;
  }

  /// Deliberately loose: an address with one @ and a dotted domain. Stricter rules reject
  /// addresses that genuinely work, and the form is not the place to adjudicate that.
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}
