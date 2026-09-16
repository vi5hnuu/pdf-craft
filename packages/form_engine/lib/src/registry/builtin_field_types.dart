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
  FieldTypeDescriptor(
    id: FieldTypes.checkbox,
    defaultSize: FractionalSize(0.05, 0.032),
    isToggle: true,
  ),
  FieldTypeDescriptor(
    id: FieldTypes.radio,
    defaultSize: FractionalSize(0.05, 0.032),
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
];
