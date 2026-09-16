import 'field_type_descriptor.dart';

/// Lookup for the registered field types.
///
/// Kept as an instance (with a shared [instance]) rather than a bag of statics
/// so tests can build a registry with just the types they care about, and so a
/// host app can register extra types without touching this package.
class FieldTypeRegistry {
  final Map<String, FieldTypeDescriptor> _byId;

  FieldTypeRegistry(Iterable<FieldTypeDescriptor> descriptors)
      : _byId = {for (final d in descriptors) d.id: d};

  static FieldTypeRegistry? _instance;

  /// The registry the app uses. Set once during start-up.
  static FieldTypeRegistry get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'FieldTypeRegistry.instance was read before register() — call '
        'FieldTypeRegistry.register(builtinFieldTypes) during start-up.',
      );
    }
    return i;
  }

  static void register(Iterable<FieldTypeDescriptor> descriptors) =>
      _instance = FieldTypeRegistry(descriptors);

  /// All registered types, in registration order (the palette's order).
  List<FieldTypeDescriptor> get all => _byId.values.toList(growable: false);

  List<String> get ids => _byId.keys.toList(growable: false);

  bool contains(String id) => _byId.containsKey(id);

  /// Descriptor for [id].
  ///
  /// Throws rather than returning null: an unknown type means a schema written
  /// by a newer build, and silently dropping the field would lose the user's
  /// work without telling anyone.
  FieldTypeDescriptor operator [](String id) {
    final d = _byId[id];
    if (d == null) {
      throw ArgumentError.value(id, 'id', 'Unknown field type. Known types: ${ids.join(', ')}');
    }
    return d;
  }

  FieldTypeDescriptor? lookup(String id) => _byId[id];
}
