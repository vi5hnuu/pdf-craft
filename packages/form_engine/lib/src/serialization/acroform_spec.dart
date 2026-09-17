import '../model/field_rules.dart';
import '../model/form_field.dart';
import '../model/form_schema.dart';
import '../model/geometry.dart';
import '../registry/builtin_field_types.dart';
import '../registry/field_type_registry.dart';

/// Stage 2 of the pipeline: schema -> the backend's `create-form` wire format.
///
/// The output must stay byte-compatible with what the editor sent before this
/// package existed, because the running backend
/// (`CreateFormRequest.FormFieldSpec`) parses it. A golden test locks the shape;
/// every rule below is carried over from the editor's old `_onSave`.
class AcroFormSpecMapper {
  final FieldTypeRegistry registry;

  const AcroFormSpecMapper(this.registry);

  /// Converts every field to one spec map.
  ///
  /// Fields on pages with no known size are skipped: without the page's size in
  /// points the fractional rect cannot be converted, and guessing would place
  /// the field somewhere wrong rather than nowhere.
  List<Map<String, Object?>> toSpecs(FormSchema schema) {
    // A rule's target may itself be a radio, whose PDF name is its group.
    final byId = schema.byId;
    String nameFor(String id) {
      final target = byId[id];
      if (target == null) return id; // dangling: send the id so the failure is visible
      return registry[target.typeId].isGrouped ? target.group : target.name;
    }

    final specs = <Map<String, Object?>>[];
    for (final field in schema.fields) {
      final points = schema.pageSizes[field.page];
      if (points == null) continue;
      specs.add(_specFor(field, points, nameFor));
    }
    return specs;
  }

  Map<String, Object?> _specFor(
      FormFieldModel f, PageSizePoints points, String Function(String) nameFor) {
    final type = registry[f.typeId];

    // A radio group is a single PDF field with one widget per option, so the
    // group name — not the per-widget name — is what the PDF must carry.
    final name = type.isGrouped ? f.group : f.name;

    // An export value is what the PDF records when this radio option is on.
    // Falling back to the field name matches the old behaviour and keeps every
    // option in a group distinct.
    final exportValue =
        type.isGrouped ? (f.exportValue.isEmpty ? f.name : f.exportValue) : null;

    return {
      'type': f.typeId,
      'name': name,
      'page': f.page - 1, // wire format is 0-indexed
      'x': f.rect.left * points.width,
      'y': f.rect.top * points.height,
      'width': f.rect.width * points.width,
      'height': f.rect.height * points.height,
      if (f.value.isNotEmpty) 'value': f.value,
      if (type.acceptsOptions) 'options': List<String>.from(f.options),
      if (exportValue != null) 'export_value': exportValue,
      // 0 means "auto" in the PDF, which the backend already defaults to, so it
      // is only worth sending a real size.
      if (type.acceptsValue && f.fontSize > 0) 'font_size': f.fontSize,
      if (f.required) 'required': true,
      if (type.isToggle) 'checked': f.checked,
      // A visible caption drawn beside the widget. `tooltip` below is /TU — hover help that
      // never reaches paper — so without this a radio group's options are three identical
      // circles with nothing to tell them apart in the output.
      if (f.label.isNotEmpty) 'label': f.label,
      if (f.label.isNotEmpty && f.labelSize > 0) 'label_size': f.labelSize,
      if (f.label.isNotEmpty) 'label_position': f.labelPosition.name,
      if (f.tooltip.isNotEmpty) 'tooltip': f.tooltip,
      if (f.readOnly) 'read_only': true,
      if (f.maxLength != null && f.maxLength! > 0) 'max_length': f.maxLength,
      // The spec only permits a comb field with a length and a single line, so the rule is
      // enforced here rather than trusting the editor to have disabled the control.
      if (f.comb && (f.maxLength ?? 0) > 0 && f.typeId != FieldTypes.multiline) 'comb': true,
      if (f.alignment != TextAlignment.left) 'alignment': f.alignment.quadding,
      if (type.allowsMultiSelect && f.multiSelect) 'multi_select': true,
      if (f.format != TextFormat.none) 'format': f.format.name,
      // Only meaningful on a date field; the backend writes it as the field's format action.
      if (f.dateFormat.isNotEmpty) 'date_format': f.dateFormat,
      if (f.validation.pattern != null && f.validation.pattern!.isNotEmpty)
        'validation_pattern': f.validation.pattern,
      // Rules travel as ids, but the PDF's own scripts address fields by NAME, so the
      // resolved names are sent alongside. Resolution happens here, where the whole schema
      // is in hand, rather than leaving the backend to guess.
      if (f.condition != null)
        'condition': {
          'parent_field': nameFor(f.condition!.parent.id),
          'operator': f.condition!.operator.name,
          'value': f.condition!.value,
        },
      if (f.calculation != null && !f.calculation!.isEmpty)
        'calculation': {
          'function': f.calculation!.function.acrobatName,
          'fields': f.calculation!.fields.map((r) => nameFor(r.id)).toList(),
        },
    };
  }
}
