import 'package:form_engine/form_engine.dart';
import 'package:test/test.dart';

void main() {
  const codec = SchemaCodec();

  FormSchema sample() => FormSchema(
        pageSizes: {1: const PageSizePoints(595, 842)},
        fields: [
          FormFieldModel(
            id: 'f1',
            typeId: FieldTypes.text,
            page: 1,
            rect: const FractionalRect(0.1, 0.2, 0.3, 0.04),
            name: 'name',
            value: 'Vishnu',
            required: true,
            fontSize: 11,
          ),
          FormFieldModel(
            id: 'f2',
            typeId: FieldTypes.radio,
            page: 1,
            rect: const FractionalRect(0.1, 0.3, 0.05, 0.03),
            name: 'yes',
            group: 'agree',
            exportValue: 'Y',
            checked: true,
          ),
        ],
      );

  test('a schema survives an encode/decode round trip unchanged', () {
    final decoded = codec.decode(codec.encode(sample()));

    expect(decoded.fields.length, 2);
    expect(decoded.pageSizes[1]!.width, 595);

    final text = decoded.fields[0];
    expect(text.id, 'f1');
    expect(text.typeId, FieldTypes.text);
    expect(text.page, 1);
    expect(text.rect, const FractionalRect(0.1, 0.2, 0.3, 0.04));
    expect(text.value, 'Vishnu');
    expect(text.required, isTrue);
    expect(text.fontSize, 11);

    final radio = decoded.fields[1];
    expect(radio.group, 'agree');
    expect(radio.exportValue, 'Y');
    expect(radio.checked, isTrue);
  });

  test('properties written by a newer build survive a load/save cycle', () {
    // An older build must not silently strip a field's new properties when the
    // user opens and re-saves a draft.
    final fromFuture = {
      'version': 1,
      'page_sizes': {
        '1': {'width': 595.0, 'height': 842.0}
      },
      'fields': [
        {
          'id': 'f1',
          'type': FieldTypes.text,
          'page': 1,
          'rect': {'left': 0.0, 'top': 0.0, 'width': 0.2, 'height': 0.05},
          'name': 'n',
          'tooltip': 'Your full legal name',
          'validation_pattern': r'^[A-Z].*$',
        }
      ],
    };

    final reEncoded = codec.encode(codec.decode(fromFuture));
    final field = (reEncoded['fields'] as List).single as Map<String, Object?>;

    expect(field['tooltip'], 'Your full legal name');
    expect(field['validation_pattern'], r'^[A-Z].*$');
  });

  test('a schema from a newer version is refused with a clear message', () {
    expect(
      () => codec.decode({'version': 99, 'fields': const [], 'page_sizes': const {}}),
      throwsA(isA<FormatException>()),
    );
  });

  test('the stored format keeps pages 1-based, unlike the wire format', () {
    final encoded = codec.encode(sample());
    final first = (encoded['fields'] as List).first as Map<String, Object?>;
    expect(first['page'], 1);
  });

  test('empty optionals are not written, keeping drafts small', () {
    final encoded = codec.encode(FormSchema(fields: [
      FormFieldModel(
        id: 'f',
        typeId: FieldTypes.text,
        page: 1,
        rect: const FractionalRect(0, 0, 0.1, 0.1),
        name: 'n',
      ),
    ]));
    final field = (encoded['fields'] as List).single as Map<String, Object?>;
    expect(field.containsKey('value'), isFalse);
    expect(field.containsKey('options'), isFalse);
    expect(field.containsKey('required'), isFalse);
  });
}
