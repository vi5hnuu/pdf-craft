/// Pure-Dart core of the PDF form builder.
///
/// Three stages, deliberately separate:
///  1. the editor produces a [FormSchema] with page-relative coordinates,
///     stored on the device via [SchemaCodec];
///  2. [AcroFormSpecMapper] turns that schema into the backend's `create-form`
///     request, which returns a PDF with real AcroForm fields;
///  3. flattening that PDF (an existing backend tool) bakes the values in.
///
/// Nothing here imports Flutter, so the model and its rules can be tested with
/// `dart test` and could later back a web builder.
library form_engine;

export 'src/logic/calculation.dart';
export 'src/logic/condition.dart';
export 'src/logic/form_runtime.dart';
export 'src/model/field_rules.dart';
export 'src/model/form_field.dart';
export 'src/model/form_schema.dart';
export 'src/model/geometry.dart';
export 'src/registry/builtin_field_types.dart';
export 'src/registry/field_type_descriptor.dart';
export 'src/registry/field_type_registry.dart';
export 'src/serialization/acroform_spec.dart';
export 'src/serialization/schema_codec.dart';
