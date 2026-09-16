/// A reference from one field's rule to another field.
///
/// Rules point at a field's **id**, never its name. A name is a label the author edits and
/// the PDF carries; an id is stable for the field's life. When rules referenced names, renaming
/// a field silently changed what its dependants computed — a total quietly went from 5 to 3
/// with no error raised — and two fields could share a name with nothing to stop them.
///
/// [name] is kept alongside purely as a human-readable hint for diffs and debugging; it is
/// refreshed on save and never used for resolution.
class FieldRef {
  final String id;
  final String? name;

  const FieldRef(this.id, [this.name]);

  Map<String, Object?> toJson() => {'id': id, if (name != null) 'name': name};

  static FieldRef fromJson(Object? json) {
    // A bare string is accepted so schemas written before ids existed still load; the
    // migration in SchemaCodec converts those to real ids.
    if (json is String) return FieldRef(json);
    final map = (json as Map).cast<String, Object?>();
    return FieldRef(map['id'] as String, map['name'] as String?);
  }

  @override
  bool operator ==(Object other) => other is FieldRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FieldRef($id${name == null ? '' : ', $name'})';
}
