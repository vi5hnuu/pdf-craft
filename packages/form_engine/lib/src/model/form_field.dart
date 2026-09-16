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
        extras: Map<String, Object?>.from(extras),
      );
}
