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

  test('toggles are sized in points, not as a fraction of the page', () {
    // A fraction gave 0.05 x 0.032 of A4 = 29.8 x 26.9pt: too big to sit on a printed form's
    // box, and not square, so the tick was drawn in an oval.
    for (final id in [FieldTypes.checkbox, FieldTypes.radio]) {
      final points = registry[id].defaultPointSize;
      expect(points, isNotNull, reason: '$id must have an absolute size');
      expect(points!.width, points.height, reason: '$id must be square');
      expect(points.width, 12);
      expect(registry[id].lockAspect, isTrue, reason: '$id must stay square when resized');
    }
  });

  test('a point size is the same size in points on any paper', () {
    const twelvePt = PointSize(12, 12);
    final onA4 = twelvePt.toFraction(595.28, 841.89);
    final onLetter = twelvePt.toFraction(612, 792);
    expect(onA4.width * 595.28, closeTo(12, 1e-9));
    expect(onA4.height * 841.89, closeTo(12, 1e-9));
    expect(onLetter.width * 612, closeTo(12, 1e-9));
    expect(onLetter.height * 792, closeTo(12, 1e-9));
    // The fractions differ between papers precisely because the points do not.
    expect(onA4.width, isNot(onLetter.width));
  });

  test('types whose size is relative to the page keep a fractional default', () {
    for (final id in [FieldTypes.text, FieldTypes.multiline, FieldTypes.signature]) {
      expect(registry[id].defaultPointSize, isNull);
      expect(registry[id].lockAspect, isFalse);
    }
  });

  test('an unknown type fails loudly instead of dropping the field', () {
    expect(() => registry['barcode'], throwsArgumentError);
    expect(registry.lookup('barcode'), isNull);
  });
}
