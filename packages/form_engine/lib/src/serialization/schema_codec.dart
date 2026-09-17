import '../logic/calculation.dart';
import '../logic/condition.dart';
import '../model/field_rules.dart';
import '../model/form_field.dart';
import '../model/recipient.dart';
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
        'version': FormSchema.currentVersion,
        if (schema.documentId != null) 'document_id': schema.documentId,
        if (schema.title != null) 'title': schema.title,
        'updated_at': (schema.updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
        if (schema.recipients.isNotEmpty)
          'recipients': schema.recipients.map((r) => r.toJson()).toList(),
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
        if (f.label.isNotEmpty) 'label': f.label,
        if (f.labelSize > 0) 'label_size': f.labelSize,
        if (f.label.isNotEmpty && f.labelPosition != LabelPosition.right)
          'label_position': f.labelPosition.name,
        if (f.tooltip.isNotEmpty) 'tooltip': f.tooltip,
        if (f.readOnly) 'read_only': true,
        if (f.maxLength != null) 'max_length': f.maxLength,
        if (f.comb) 'comb': true,
        if (f.alignment != TextAlignment.left) 'alignment': f.alignment.name,
        if (f.multiSelect) 'multi_select': true,
        if (f.format != TextFormat.none) 'format': f.format.name,
        if (f.dateFormat.isNotEmpty) 'date_format': f.dateFormat,
        if (!f.validation.isEmpty) 'validation': f.validation.toJson(),
        if (f.condition != null) 'condition': f.condition!.toJson(),
        if (f.calculation != null && !f.calculation!.isEmpty)
          'calculation': f.calculation!.toJson(),
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
      documentId: migrated['document_id'] as String?,
      title: migrated['title'] as String?,
      updatedAt: DateTime.tryParse(migrated['updated_at'] as String? ?? ''),
      recipients: ((migrated['recipients'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(Recipient.fromJson)
          .toList(),
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
      'label', 'label_size', 'label_position',
      'tooltip', 'read_only', 'max_length', 'comb', 'alignment', 'multi_select',
      'format', 'date_format', 'validation', 'condition', 'calculation',
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
      label: json['label'] as String? ?? '',
      labelSize: (json['label_size'] as num?)?.toDouble() ?? 0,
      labelPosition: LabelPosition.fromWire(json['label_position'] as String?),
      tooltip: json['tooltip'] as String? ?? '',
      readOnly: json['read_only'] as bool? ?? false,
      maxLength: (json['max_length'] as num?)?.toInt(),
      comb: json['comb'] as bool? ?? false,
      alignment: TextAlignment.fromWire(json['alignment'] as String?),
      multiSelect: json['multi_select'] as bool? ?? false,
      format: TextFormat.fromWire(json['format'] as String?),
      dateFormat: json['date_format'] as String? ?? '',
      validation: json['validation'] == null
          ? const FieldValidation()
          : FieldValidation.fromJson((json['validation'] as Map).cast<String, Object?>()),
      condition: json['condition'] == null
          ? null
          : VisibilityCondition.fromJson((json['condition'] as Map).cast<String, Object?>()),
      calculation: json['calculation'] == null
          ? null
          : Calculation.fromJson((json['calculation'] as Map).cast<String, Object?>()),
      // Anything this build does not recognise rides along untouched.
      extras: {
        for (final e in json.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Applies migrations in order, oldest first.
  Map<String, Object?> _migrate(Map<String, Object?> json, {required int from}) {
    var result = json;
    if (from < 2) result = _v1ToV2(result);
    return result;
  }

  /// v1 -> v2: rules referenced field *names*; they now reference ids.
  ///
  /// Every v1 draft is rewritten by looking each name up in the same document. A name that no
  /// longer resolves is left as-is and surfaces later as a dangling reference, which is
  /// honest — it was already broken, and silently dropping the rule would hide that.
  Map<String, Object?> _v1ToV2(Map<String, Object?> json) {
    final fields = ((json['fields'] as List?) ?? const []).cast<Map<String, Object?>>();
    final idByName = <String, String>{
      for (final f in fields)
        if (f['name'] is String && f['id'] is String) f['name'] as String: f['id'] as String,
    };

    Object? refFor(Object? name) {
      if (name is! String) return name;
      final id = idByName[name];
      return id == null ? {'id': name, 'name': name} : {'id': id, 'name': name};
    }

    for (final f in fields) {
      final condition = f['condition'];
      if (condition is Map) {
        // A fresh map, not cast(): a cast view keeps the source's value type, so writing the
        // new reference object into a slot that held a String throws at runtime.
        final map = Map<String, Object?>.of(condition.cast<String, Object?>());
        if (map['parent'] == null && map['parent_field'] != null) {
          map['parent'] = refFor(map['parent_field']);
          map.remove('parent_field');
        }
        f['condition'] = map;
      }
      final calculation = f['calculation'];
      if (calculation is Map) {
        final map = Map<String, Object?>.of(calculation.cast<String, Object?>());
        final names = map['fields'];
        if (names is List) map['fields'] = names.map(refFor).toList();
        f['calculation'] = map;
      }
    }
    return json;
  }
}
