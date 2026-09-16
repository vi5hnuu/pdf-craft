import '../model/form_field.dart';
import '../model/form_schema.dart';
import '../model/geometry.dart';
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
    final specs = <Map<String, Object?>>[];
    for (final field in schema.fields) {
      final points = schema.pageSizes[field.page];
      if (points == null) continue;
      specs.add(_specFor(field, points));
    }
    return specs;
  }

  Map<String, Object?> _specFor(FormFieldModel f, PageSizePoints points) {
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
    };
  }
}
