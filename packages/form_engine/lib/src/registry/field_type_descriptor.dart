import '../model/geometry.dart';

/// Everything the engine needs to know about one field type.
///
/// This is the extension point of the whole engine. Before it, a field type was
/// spread across eight `switch` statements in the editor; now a type is one
/// object, and the places that used to switch just ask the registry. Adding a
/// type touches this registration and the UI's presentation entry — nothing else.
class FieldTypeDescriptor {
  /// Registry key and wire value, e.g. `text`. Stable forever: saved schemas and
  /// the backend both store this string.
  final String id;

  /// Size a freshly dropped field gets, as a fraction of the page.
  final FractionalSize defaultSize;

  /// Checkbox-like: holds an on/off state rather than text.
  final bool isToggle;

  /// Carries a list of choices (dropdown, listbox).
  final bool acceptsOptions;

  /// Can hold a text value the filler types or that is prefilled.
  final bool acceptsValue;

  /// Part of a radio group, where the group name is the real PDF field name.
  final bool isGrouped;

  /// Drawn/applied signature rather than data entry. Kept as its own flag so a
  /// certified eSign provider (Aadhaar eSign, DSC) can later be attached to
  /// exactly these fields without reinterpreting other types.
  final bool isSignature;

  const FieldTypeDescriptor({
    required this.id,
    required this.defaultSize,
    this.isToggle = false,
    this.acceptsOptions = false,
    this.acceptsValue = false,
    this.isGrouped = false,
    this.isSignature = false,
  });
}
