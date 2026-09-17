import '../model/field_rules.dart';
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
  ///
  /// Used only when [defaultPointSize] is null: a fraction is right for a field whose size is
  /// relative to the page (a text box spanning a third of the width), and wrong for one whose
  /// size is absolute (a checkbox is 12pt whatever the paper).
  final FractionalSize defaultSize;

  /// Size in PDF points a freshly dropped field gets, when the type has an absolute size.
  ///
  /// Checkboxes and radios are the case this exists for. As fractions of A4 they came out
  /// 29.8 x 26.9pt — far larger than any printed form's box, and not even square, because the
  /// same fraction means different points on each axis.
  final PointSize? defaultPointSize;

  /// Width and height move together, so the field can only ever be square.
  ///
  /// The PDF draws a checkbox's tick and a radio's ring against `min(width, height)`, so a
  /// non-square toggle puts a round glyph in an oval box. Nothing good comes of it.
  final bool lockAspect;

  /// Checkbox-like: holds an on/off state rather than text.
  final bool isToggle;

  /// Carries a list of choices (dropdown, listbox).
  final bool acceptsOptions;

  /// Can hold a text value the filler types or that is prefilled.
  final bool acceptsValue;

  /// Part of a radio group, where the group name is the real PDF field name.
  final bool isGrouped;

  /// Accepts more than one selected option (a list box rather than a dropdown).
  final bool allowsMultiSelect;

  /// What this type expects by default. A `number` field is still a PDF text field; the
  /// format is what gives it a numeric keyboard, numeric validation and a format action.
  final TextFormat defaultFormat;

  /// Drawn/applied signature rather than data entry. Kept as its own flag so a
  /// certified eSign provider (Aadhaar eSign, DSC) can later be attached to
  /// exactly these fields without reinterpreting other types.
  final bool isSignature;

  const FieldTypeDescriptor({
    required this.id,
    required this.defaultSize,
    this.defaultPointSize,
    this.lockAspect = false,
    this.isToggle = false,
    this.acceptsOptions = false,
    this.acceptsValue = false,
    this.isGrouped = false,
    this.isSignature = false,
    this.allowsMultiSelect = false,
    this.defaultFormat = TextFormat.none,
  });
}
