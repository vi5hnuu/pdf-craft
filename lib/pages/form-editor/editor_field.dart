/// The editor's mutable working copy of a form field.
///
/// Separate from the engine's immutable `FormFieldModel`: the canvas drags and edits this
/// one, and it is converted to a schema on save.
library;

import 'package:flutter/material.dart';
import 'package:form_engine/form_engine.dart' as engine;
import 'package:pdf_craft/pages/form-editor/form_field_type.dart';

/// A placed form field. [rect] is stored in **fractional** page coordinates
/// (0..1), which makes it independent of zoom and per-page pixel size.
class EditorField {
  final String id;
  FieldType type;
  Rect rect;
  String name;
  String value = '';
  List<String> options = ['Option 1', 'Option 2'];
  /// Radio group this option belongs to. Every option sharing a group behaves as one
  /// PDF field, so only one of them can be on at a time.
  ///
  /// Assigned per placement rather than defaulting to a shared constant: a bank form has
  /// several independent questions ("Account type", "Marital status"), and a shared default
  /// silently merged them into one group where choosing Savings cleared Married.
  String group = '';
  String exportValue = '';
  double fontSize = 0;
  bool required = false;
  bool checked = false; // checkbox/radio prefill (on by default)

  // ── Rich properties, carried straight through to the engine schema ──────────────
  String tooltip = '';
  bool readOnly = false;
  int maxLength = 0; // 0 = no cap
  bool comb = false;
  engine.TextAlignment alignment = engine.TextAlignment.left;
  bool multiSelect = false;
  String validationPattern = '';
  /// What the author typed in the inspector, shown back to them verbatim.
  ///
  /// The authoritative link is [conditionRef] / [calcRefs]: those hold the resolved **id**,
  /// captured the moment the name is entered. Resolving at save time instead meant that
  /// renaming the target first left the lookup with nothing to find, and the rule silently
  /// degraded to a dangling reference.
  String conditionField = '';
  engine.ConditionOperator conditionOperator = engine.ConditionOperator.equals;
  String conditionValue = '';
  engine.CalculationFunction calcFunction = engine.CalculationFunction.sum;
  /// Comma-separated field names feeding the calculation, as typed.
  String calcFields = '';

  /// Resolved reference for [conditionField], captured when it was entered.
  engine.FieldRef? conditionRef;

  /// Resolved references for [calcFields], captured when they were entered.
  List<engine.FieldRef> calcRefs = const [];

  EditorField({required this.type, required this.rect, required this.name}) : id = UniqueKey().toString();
}
