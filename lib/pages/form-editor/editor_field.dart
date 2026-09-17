/// The editor's mutable working copy of a form field.
///
/// Separate from the engine's immutable `FormFieldModel`: the canvas drags and edits this
/// one, and it is converted to a schema on save.
library;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
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
  /// Choices for a dropdown or list field.
  ///
  /// Localized, because these are not placeholders: they are written into the PDF as the
  /// field's option values, so a Hindi author who does not edit them ships an English form.
  List<String> options = [
    L10n.current.optionLabelDefault(1),
    L10n.current.optionLabelDefault(2),
  ];
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

  /// Caption drawn on the page next to the field, in the editor and in the produced PDF.
  ///
  /// The thing a radio group needs most: three circles that all look the same are useless
  /// without "Savings", "Current", "Salary" beside them. Left empty when the document already
  /// prints its own labels, which is the bank-form case.
  String label = '';

  /// Point size for [label]. 0 lets the backend choose.
  double labelSize = 0;

  /// Which side of the field the caption sits on.
  engine.LabelPosition labelPosition = engine.LabelPosition.right;

  String tooltip = '';
  bool readOnly = false;
  int maxLength = 0; // 0 = no cap
  bool comb = false;
  engine.TextAlignment alignment = engine.TextAlignment.left;
  bool multiSelect = false;
  String validationPattern = '';

  /// Bounds the engine's runtime already enforces but the inspector never exposed, so a number
  /// field could not be constrained from the UI at all.
  String minValue = '';
  String maxValue = '';
  String minLength = '';

  /// Date display format, written into the PDF as the field's format action. Without one a date
  /// field was just a text box and every filler typed a different shape of date.
  String dateFormat = 'dd/mm/yyyy';
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
