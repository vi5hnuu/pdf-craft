import 'package:form_engine/form_engine.dart';
import 'package:test/test.dart';

void main() {
  final registry = FieldTypeRegistry(builtinFieldTypes);

  test('every field type the editor shipped is registered', () {
    expect(
      registry.ids,
      containsAll([
        FieldTypes.text,
        FieldTypes.multiline,
        FieldTypes.checkbox,
        FieldTypes.radio,
        FieldTypes.dropdown,
        FieldTypes.date,
        FieldTypes.signature,
      ]),
    );
  });

  test('type ids are unique', () {
    final ids = builtinFieldTypes.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('flags match the behaviour the editor had before extraction', () {
    expect(registry[FieldTypes.checkbox].isToggle, isTrue);
    expect(registry[FieldTypes.radio].isToggle, isTrue);
    expect(registry[FieldTypes.radio].isGrouped, isTrue);
    expect(registry[FieldTypes.dropdown].acceptsOptions, isTrue);
    expect(registry[FieldTypes.text].acceptsValue, isTrue);
    expect(registry[FieldTypes.multiline].acceptsValue, isTrue);
    expect(registry[FieldTypes.date].acceptsValue, isTrue);
    expect(registry[FieldTypes.signature].isSignature, isTrue);
  });

  test('default sizes are unchanged from the original editor', () {
    expect(registry[FieldTypes.multiline].defaultSize, const FractionalSize(0.42, 0.12));
    expect(registry[FieldTypes.checkbox].defaultSize, const FractionalSize(0.05, 0.032));
    expect(registry[FieldTypes.signature].defaultSize, const FractionalSize(0.32, 0.08));
    expect(registry[FieldTypes.text].defaultSize, const FractionalSize(0.36, 0.045));
  });

  test('an unknown type fails loudly instead of dropping the field', () {
    expect(() => registry['barcode'], throwsArgumentError);
    expect(registry.lookup('barcode'), isNull);
  });
}
