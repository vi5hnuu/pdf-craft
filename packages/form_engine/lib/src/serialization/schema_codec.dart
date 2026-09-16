import '../model/form_field.dart';
import '../model/form_schema.dart';
import '../model/geometry.dart';

/// Stage 1 of the pipeline: the schema as stored on the device.
///
/// This is the editor's own document format — a draft the user can leave and
/// come back to. It is deliberately *not* the backend wire format: that one is
/// lossy (it drops ids, recipients and anything the current build does not
/// understand) and 0-indexed, which would make it a poor save file.
class SchemaCodec {
  const SchemaCodec();

  Map<String, Object?> encode(FormSchema schema) => {
        'version': schema.version,
        'page_sizes': {
          for (final e in schema.pageSizes.entries)
            e.key.toString(): {'width': e.value.width, 'height': e.value.height},
        },
        'fields': schema.fields.map(_encodeField).toList(),
      };

  Map<String, Object?> _encodeField(FormFieldModel f) => {
        // Unknown-to-this-build properties are written back first so a real
        // property can never be overwritten by a stale extra of the same name.
        ...f.extras,
        'id': f.id,
        'type': f.typeId,
        'page': f.page,
        'rect': f.rect.toJson(),
        'name': f.name,
        if (f.value.isNotEmpty) 'value': f.value,
        if (f.options.isNotEmpty) 'options': f.options,
        if (f.group.isNotEmpty) 'group': f.group,
        if (f.exportValue.isNotEmpty) 'export_value': f.exportValue,
        if (f.fontSize > 0) 'font_size': f.fontSize,
        if (f.required) 'required': true,
        if (f.checked) 'checked': true,
        if (f.recipientId != null) 'recipient_id': f.recipientId,
      };

  /// Reads a stored schema, migrating it forward if it was written by an older
  /// version. Throws [FormatException] on input this build cannot make sense of,
  /// so a corrupt draft surfaces instead of silently opening empty.
  FormSchema decode(Map<String, Object?> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > FormSchema.currentVersion) {
      throw FormatException(
        'Form was saved by a newer version of the app (schema v$version, '
        'this build reads up to v${FormSchema.currentVersion}).',
      );
    }
    final migrated = _migrate(json, from: version);

    final rawFields = (migrated['fields'] as List?) ?? const [];
    final rawSizes = (migrated['page_sizes'] as Map?) ?? const {};

    return FormSchema(
      version: FormSchema.currentVersion,
      pageSizes: {
        for (final e in rawSizes.entries)
          int.parse(e.key as String): PageSizePoints(
            ((e.value as Map)['width'] as num).toDouble(),
            ((e.value as Map)['height'] as num).toDouble(),
          ),
      },
      fields: rawFields
          .cast<Map<String, Object?>>()
          .map(_decodeField)
          .toList(),
    );
  }

  FormFieldModel _decodeField(Map<String, Object?> json) {
    const known = {
      'id', 'type', 'page', 'rect', 'name', 'value', 'options', 'group',
      'export_value', 'font_size', 'required', 'checked', 'recipient_id',
    };
    return FormFieldModel(
      id: json['id'] as String,
      typeId: json['type'] as String,
      page: (json['page'] as num).toInt(),
      rect: FractionalRect.fromJson((json['rect'] as Map).cast<String, Object?>()),
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      options: (json['options'] as List?)?.cast<String>().toList() ?? <String>[],
      group: json['group'] as String? ?? '',
      exportValue: json['export_value'] as String? ?? '',
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 0,
      required: json['required'] as bool? ?? false,
      checked: json['checked'] as bool? ?? false,
      recipientId: json['recipient_id'] as String?,
      // Anything this build does not recognise rides along untouched.
      extras: {
        for (final e in json.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Applies migrations in order. Empty today (v1 is the first format); the hook
  /// exists so the first breaking change is a small addition here rather than a
  /// redesign of loading.
  Map<String, Object?> _migrate(Map<String, Object?> json, {required int from}) => json;
}
