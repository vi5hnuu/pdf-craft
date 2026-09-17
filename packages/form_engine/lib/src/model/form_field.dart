import '../logic/calculation.dart';
import '../logic/condition.dart';
import 'field_rules.dart';
import 'geometry.dart';

/// One placed field in a form.
///
/// Deliberately a single concrete class keyed by a [typeId] string rather than a
/// sealed class hierarchy: behaviour for a type lives in its
/// `FieldTypeDescriptor`, so adding a type never means adding a subclass, a new
/// `switch` arm, or a change to this file.
class FormFieldModel {
  /// Stable identity for this field within the schema (not shown to the user).
  final String id;

  /// Registry key, e.g. `text`. Also the value sent on the wire — never reuse an
  /// id for a different meaning, or old saved schemas change behaviour.
  String typeId;

  /// 1-based page the field sits on. The wire format is 0-based; the mapper
  /// converts. Kept 1-based here because every UI surface counts pages from 1.
  int page;

  /// Position as a fraction of the page (see [FractionalRect]).
  FractionalRect rect;

  /// Field name written into the PDF. For radio buttons the *group* name is what
  /// the PDF uses, so [group] wins there — see `AcroFormSpecMapper`.
  String name;

  /// Default/prefilled value.
  String value;

  /// Choices for option-bearing types (dropdown, listbox).
  List<String> options;

  /// Radio group name: every radio sharing a group behaves as one PDF field.
  String group;

  /// Radio widget's export value — what the PDF records when this option is on.
  String exportValue;

  /// 0 means "auto size to the field", matching the PDF convention.
  double fontSize;

  bool required;

  /// Checkbox/radio prefilled as on.
  bool checked;

  /// Visible caption drawn on the page beside the field.
  ///
  /// Not the same thing as [tooltip], which is `/TU` — hover help that never appears on paper
  /// and that most mobile readers do not show at all. A radio group's options are otherwise
  /// indistinguishable in the output: three identical circles with nothing to say which is
  /// "Savings" and which is "Current". Empty means draw nothing, which is right when the
  /// document already prints its own labels.
  String label;

  /// Point size for [label]. 0 takes the backend's default.
  double labelSize;

  /// Which side of the field the caption sits on.
  LabelPosition labelPosition;

  /// Help text shown on hover/long-press and written to the PDF as `/TU`.
  String tooltip;

  /// Filled in already and not editable (a reference number, a pre-agreed date).
  bool readOnly;

  /// Character cap. Also what a comb field divides itself into.
  int? maxLength;

  /// Draws the field as [maxLength] equally spaced boxes, the way a form asks for a PIN or
  /// a reference code one character per cell. The PDF spec only allows this with a maxLength
  /// and on a single-line field, which [AcroFormSpecMapper] enforces.
  bool comb;

  /// Text justification inside the box.
  TextAlignment alignment;

  /// Whether a list field accepts more than one selection.
  bool multiSelect;

  /// What the field expects, which drives keyboard, validation and PDF format actions.
  TextFormat format;

  /// Display format for a date field, e.g. `dd/mm/yyyy`. Empty for every other type.
  String dateFormat;

  /// Input rules enforced by the app's own runtime.
  FieldValidation validation;

  /// Shows this field only when another field holds a given value.
  VisibilityCondition? condition;

  /// Derives this field's value from other fields.
  Calculation? calculation;

  /// Role this field belongs to. Single-device filling ignores it today; it
  /// exists from the start so multi-party sending is additive later rather than
  /// a schema migration.
  String? recipientId;

  /// Properties this build does not know about, preserved verbatim through a
  /// load/save cycle so a schema written by a newer version is not silently
  /// stripped when an older build opens it.
  final Map<String, Object?> extras;

  FormFieldModel({
    required this.id,
    required this.typeId,
    required this.page,
    required this.rect,
    required this.name,
    this.value = '',
    List<String>? options,
    this.group = '',
    this.exportValue = '',
    this.fontSize = 0,
    this.required = false,
    this.checked = false,
    this.recipientId,
    this.label = '',
    this.labelSize = 0,
    this.labelPosition = LabelPosition.right,
    this.tooltip = '',
    this.readOnly = false,
    this.maxLength,
    this.comb = false,
    this.alignment = TextAlignment.left,
    this.multiSelect = false,
    this.format = TextFormat.none,
    this.dateFormat = '',
    this.validation = const FieldValidation(),
    this.condition,
    this.calculation,
    Map<String, Object?>? extras,
  })  : options = options ?? <String>[],
        extras = extras ?? <String, Object?>{};

  FormFieldModel copyWith({
    String? typeId,
    int? page,
    FractionalRect? rect,
    String? name,
    String? value,
    List<String>? options,
    String? group,
    String? exportValue,
    double? fontSize,
    bool? required,
    bool? checked,
    String? recipientId,
    String? label,
    double? labelSize,
    LabelPosition? labelPosition,
    String? tooltip,
    bool? readOnly,
    int? maxLength,
    bool? comb,
    TextAlignment? alignment,
    bool? multiSelect,
    TextFormat? format,
    String? dateFormat,
    FieldValidation? validation,
    VisibilityCondition? condition,
    Calculation? calculation,
  }) =>
      FormFieldModel(
        id: id,
        typeId: typeId ?? this.typeId,
        page: page ?? this.page,
        rect: rect ?? this.rect,
        name: name ?? this.name,
        value: value ?? this.value,
        options: options ?? List<String>.from(this.options),
        group: group ?? this.group,
        exportValue: exportValue ?? this.exportValue,
        fontSize: fontSize ?? this.fontSize,
        required: required ?? this.required,
        checked: checked ?? this.checked,
        recipientId: recipientId ?? this.recipientId,
        label: label ?? this.label,
        labelSize: labelSize ?? this.labelSize,
        labelPosition: labelPosition ?? this.labelPosition,
        tooltip: tooltip ?? this.tooltip,
        readOnly: readOnly ?? this.readOnly,
        maxLength: maxLength ?? this.maxLength,
        comb: comb ?? this.comb,
        alignment: alignment ?? this.alignment,
        multiSelect: multiSelect ?? this.multiSelect,
        format: format ?? this.format,
        dateFormat: dateFormat ?? this.dateFormat,
        validation: validation ?? this.validation,
        condition: condition ?? this.condition,
        calculation: calculation ?? this.calculation,
        extras: Map<String, Object?>.from(extras),
      );
}
