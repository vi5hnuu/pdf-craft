import '../model/field_rules.dart';
import '../model/geometry.dart';
import 'field_type_descriptor.dart';

/// Field type ids. Referenced by name across the engine, the UI and the backend,
/// so they are constants rather than loose strings.
abstract final class FieldTypes {
  static const text = 'text';
  static const multiline = 'multiline';
  static const checkbox = 'checkbox';
  static const radio = 'radio';
  static const dropdown = 'dropdown';
  static const date = 'date';
  static const signature = 'signature';

  // Added once the registry made a type a single registration rather than eight switch arms.
  static const number = 'number';
  static const email = 'email';
  static const phone = 'phone';
  static const listbox = 'listbox';
}

/// The types shipped today, in palette order.
///
/// Sizes and flags are carried over verbatim from the editor's former
/// `FieldTypeX` switches so the extraction changes no behaviour.
const List<FieldTypeDescriptor> builtinFieldTypes = [
  FieldTypeDescriptor(
    id: FieldTypes.text,
    defaultSize: FractionalSize(0.36, 0.045),
    acceptsValue: true,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.multiline,
    defaultSize: FractionalSize(0.42, 0.12),
    acceptsValue: true,
  ),
  // Square and sized in points, not as a fraction: the former FractionalSize(0.05, 0.032) was
  // 29.8 x 26.9pt on A4, too big for a printed form's box and not even square, so the tick sat
  // in an oval. 18pt is a comfortable default — big enough to see and grab on a phone — and the
  // inspector's Position & size box types an exact figure when one has to match a printed box.
  FieldTypeDescriptor(
    id: FieldTypes.checkbox,
    defaultSize: FractionalSize(0.05, 0.032),
    defaultPointSize: PointSize(18, 18),
    lockAspect: true,
    isToggle: true,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.radio,
    defaultSize: FractionalSize(0.05, 0.032),
    defaultPointSize: PointSize(18, 18),
    lockAspect: true,
    isToggle: true,
    isGrouped: true,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.dropdown,
    defaultSize: FractionalSize(0.36, 0.045),
    acceptsOptions: true,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.date,
    defaultSize: FractionalSize(0.36, 0.045),
    acceptsValue: true,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.signature,
    defaultSize: FractionalSize(0.32, 0.08),
    isSignature: true,
  ),
  // Each of the following is a PDF text field; the format is what makes it behave like a
  // number, an address or a phone number in the app and in desktop readers.
  FieldTypeDescriptor(
    id: FieldTypes.number,
    defaultSize: FractionalSize(0.22, 0.045),
    acceptsValue: true,
    defaultFormat: TextFormat.number,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.email,
    defaultSize: FractionalSize(0.42, 0.045),
    acceptsValue: true,
    defaultFormat: TextFormat.email,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.phone,
    defaultSize: FractionalSize(0.30, 0.045),
    acceptsValue: true,
    defaultFormat: TextFormat.phone,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.listbox,
    defaultSize: FractionalSize(0.36, 0.12),
    acceptsOptions: true,
    acceptsValue: true,
    allowsMultiSelect: true,
  ),
];
