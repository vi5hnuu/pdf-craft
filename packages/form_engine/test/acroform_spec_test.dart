import 'package:form_engine/form_engine.dart';
import 'package:test/test.dart';

/// These tests lock the `create-form` wire contract.
///
/// The running backend parses this shape, so a change here that is not matched
/// by a backend change silently produces PDFs with missing or misplaced fields.
void main() {
  final registry = FieldTypeRegistry(builtinFieldTypes);
  final mapper = AcroFormSpecMapper(registry);

  FormSchema schemaWith(List<FormFieldModel> fields) => FormSchema(
        fields: fields,
        pageSizes: {1: const PageSizePoints(595, 842)},
      );

  test('a field on a page with no recorded size is dropped, not guessed at', () {
    // This is the contract the editor has to respect: a fractional rect cannot become points
    // without a page size, so the mapper refuses rather than inventing A4. The editor records
    // page sizes as it renders pages and must restore them with a draft — when it did not,
    // re-opening a multi-page draft and pressing Create silently lost every field on a page
    // the author had not opened in that session.
    final specs = mapper.toSpecs(FormSchema(
      pageSizes: {1: const PageSizePoints(595, 842)},
      fields: [
        FormFieldModel(
          id: 'onPage1',
          typeId: FieldTypes.text,
          page: 1,
          rect: const FractionalRect(0.1, 0.1, 0.2, 0.05),
          name: 'kept',
        ),
        FormFieldModel(
          id: 'onPage2',
          typeId: FieldTypes.text,
          page: 2,
          rect: const FractionalRect(0.1, 0.1, 0.2, 0.05),
          name: 'dropped',
        ),
      ],
    ));

    expect(specs.map((s) => s['name']), ['kept']);
  });

  test('fractional rect is converted to PDF points against the page size', () {
    final specs = mapper.toSpecs(schemaWith([
      FormFieldModel(
        id: 'a',
        typeId: FieldTypes.text,
        page: 1,
        rect: const FractionalRect(0.1, 0.2, 0.5, 0.05),
        name: 'field1',
      ),
    ]));

    expect(specs.single['x'], closeTo(59.5, 1e-9));
    expect(specs.single['y'], closeTo(168.4, 1e-9));
    expect(specs.single['width'], closeTo(297.5, 1e-9));
    expect(specs.single['height'], closeTo(42.1, 1e-9));
  });

  test('page numbers are converted from 1-based to the wire 0-based form', () {
    final schema = FormSchema(
      fields: [
        FormFieldModel(
          id: 'a',
          typeId: FieldTypes.text,
          page: 3,
          rect: const FractionalRect(0, 0, 0.1, 0.1),
          name: 'f',
        ),
      ],
      pageSizes: {3: const PageSizePoints(595, 842)},
    );
    expect(mapper.toSpecs(schema).single['page'], 2);
  });

  test('a radio sends its group as the field name and its own name as the export value', () {
    final specs = mapper.toSpecs(schemaWith([
      FormFieldModel(
        id: 'a',
        typeId: FieldTypes.radio,
        page: 1,
        rect: const FractionalRect(0, 0, 0.05, 0.03),
        name: 'optionA',
        group: 'colour',
      ),
    ]));

    expect(specs.single['name'], 'colour');
    expect(specs.single['export_value'], 'optionA');
  });

  test('an explicit export value wins over the field name', () {
    final specs = mapper.toSpecs(schemaWith([
      FormFieldModel(
        id: 'a',
        typeId: FieldTypes.radio,
        page: 1,
        rect: const FractionalRect(0, 0, 0.05, 0.03),
        name: 'optionA',
        group: 'colour',
        exportValue: 'RED',
      ),
    ]));
    expect(specs.single['export_value'], 'RED');
  });

  test('optional properties are omitted rather than sent as null', () {
    final specs = mapper.toSpecs(schemaWith([
      FormFieldModel(
        id: 'a',
        typeId: FieldTypes.text,
        page: 1,
        rect: const FractionalRect(0, 0, 0.1, 0.1),
        name: 'f',
      ),
    ]));

    final spec = specs.single;
    expect(spec.containsKey('value'), isFalse);
    expect(spec.containsKey('options'), isFalse);
    expect(spec.containsKey('export_value'), isFalse);
    expect(spec.containsKey('font_size'), isFalse);
    expect(spec.containsKey('required'), isFalse);
    expect(spec.containsKey('checked'), isFalse);
  });

  test('only option-bearing types send options, and only toggles send checked', () {
    final specs = mapper.toSpecs(schemaWith([
      FormFieldModel(
        id: 'a',
        typeId: FieldTypes.dropdown,
        page: 1,
        rect: const FractionalRect(0, 0, 0.1, 0.1),
        name: 'd',
        options: ['x', 'y'],
      ),
      FormFieldModel(
        id: 'b',
        typeId: FieldTypes.checkbox,
        page: 1,
        rect: const FractionalRect(0, 0, 0.05, 0.03),
        name: 'c',
        checked: true,
      ),
    ]));

    expect(specs[0]['options'], ['x', 'y']);
    expect(specs[0].containsKey('checked'), isFalse);
    expect(specs[1]['checked'], true);
    expect(specs[1].containsKey('options'), isFalse);
  });

  test('font size is sent only for value-bearing types and only when set', () {
    final specs = mapper.toSpecs(schemaWith([
      FormFieldModel(
        id: 'a',
        typeId: FieldTypes.text,
        page: 1,
        rect: const FractionalRect(0, 0, 0.1, 0.1),
        name: 'f',
        fontSize: 12,
      ),
      FormFieldModel(
        id: 'b',
        typeId: FieldTypes.signature,
        page: 1,
        rect: const FractionalRect(0, 0, 0.1, 0.1),
        name: 's',
        fontSize: 12,
      ),
    ]));

    expect(specs[0]['font_size'], 12);
    expect(specs[1].containsKey('font_size'), isFalse,
        reason: 'a signature has no text to size');
  });

  test('fields on a page with no known size are skipped, not misplaced', () {
    final schema = FormSchema(
      fields: [
        FormFieldModel(
          id: 'a',
          typeId: FieldTypes.text,
          page: 9,
          rect: const FractionalRect(0, 0, 0.1, 0.1),
          name: 'f',
        ),
      ],
      pageSizes: {1: const PageSizePoints(595, 842)},
    );
    expect(mapper.toSpecs(schema), isEmpty);
  });
}
