import 'package:form_engine/form_engine.dart';
import 'package:test/test.dart';

/// The rich field properties have to survive two very different journeys: into the device
/// draft and back, and out to the backend's create-form request.
void main() {
  final registry = FieldTypeRegistry(builtinFieldTypes);
  final mapper = AcroFormSpecMapper(registry);
  const codec = SchemaCodec();

  FormFieldModel rich() => FormFieldModel(
        id: 'f1',
        typeId: FieldTypes.number,
        page: 1,
        rect: const FractionalRect(0.1, 0.1, 0.2, 0.05),
        name: 'amount',
        tooltip: 'Total before tax',
        readOnly: true,
        maxLength: 8,
        comb: true,
        alignment: TextAlignment.right,
        format: TextFormat.number,
        validation: const FieldValidation(pattern: r'^\d+$', min: 0, max: 1000),
        condition: const VisibilityCondition(
            parentField: 'paying', operator: ConditionOperator.equals, value: 'yes'),
        calculation:
            const Calculation(function: CalculationFunction.sum, fields: ['a', 'b']),
      );

  FormSchema schemaOf(List<FormFieldModel> fields) =>
      FormSchema(fields: fields, pageSizes: {1: const PageSizePoints(595, 842)});

  test('every rich property survives a draft round trip', () {
    final decoded = codec.decode(codec.encode(schemaOf([rich()]))).fields.single;

    expect(decoded.tooltip, 'Total before tax');
    expect(decoded.readOnly, isTrue);
    expect(decoded.maxLength, 8);
    expect(decoded.comb, isTrue);
    expect(decoded.alignment, TextAlignment.right);
    expect(decoded.format, TextFormat.number);
    expect(decoded.validation.pattern, r'^\d+$');
    expect(decoded.validation.min, 0);
    expect(decoded.validation.max, 1000);
    expect(decoded.condition!.parentField, 'paying');
    expect(decoded.calculation!.function, CalculationFunction.sum);
    expect(decoded.calculation!.fields, ['a', 'b']);
  });

  test('the wire format carries the new properties for the backend', () {
    final spec = mapper.toSpecs(schemaOf([rich()])).single;

    expect(spec['tooltip'], 'Total before tax');
    expect(spec['read_only'], true);
    expect(spec['max_length'], 8);
    expect(spec['comb'], true);
    expect(spec['alignment'], 2, reason: 'right maps to PDF quadding 2');
    expect(spec['format'], 'number');
    expect(spec['validation_pattern'], r'^\d+$');
    expect((spec['condition'] as Map)['parent_field'], 'paying');
    expect((spec['calculation'] as Map)['function'], 'SUM',
        reason: 'the PDF helper takes SUM/AVG/PRD/MIN/MAX');
  });

  test('comb is withheld unless the PDF would accept it', () {
    // The spec allows comb only with a MaxLen and on a single-line field.
    final noLength = rich().copyWith(maxLength: 0);
    expect(mapper.toSpecs(schemaOf([noLength])).single.containsKey('comb'), isFalse);

    final multiline = FormFieldModel(
      id: 'f2',
      typeId: FieldTypes.multiline,
      page: 1,
      rect: const FractionalRect(0, 0, 0.4, 0.1),
      name: 'notes',
      maxLength: 50,
      comb: true,
    );
    expect(mapper.toSpecs(schemaOf([multiline])).single.containsKey('comb'), isFalse);
  });

  test('multi-select is only sent for a type that supports it', () {
    final listbox = FormFieldModel(
      id: 'l',
      typeId: FieldTypes.listbox,
      page: 1,
      rect: const FractionalRect(0, 0, 0.3, 0.12),
      name: 'langs',
      options: ['A', 'B'],
      multiSelect: true,
    );
    expect(mapper.toSpecs(schemaOf([listbox])).single['multi_select'], true);

    final text = FormFieldModel(
      id: 't',
      typeId: FieldTypes.text,
      page: 1,
      rect: const FractionalRect(0, 0, 0.3, 0.05),
      name: 'plain',
      multiSelect: true,
    );
    expect(mapper.toSpecs(schemaOf([text])).single.containsKey('multi_select'), isFalse);
  });

  test('a plain field still produces the original minimal request', () {
    // The backend has to keep accepting what it always accepted.
    final plain = FormFieldModel(
      id: 'p',
      typeId: FieldTypes.text,
      page: 1,
      rect: const FractionalRect(0, 0, 0.3, 0.05),
      name: 'plain',
    );
    expect(mapper.toSpecs(schemaOf([plain])).single.keys.toSet(),
        {'type', 'name', 'page', 'x', 'y', 'width', 'height'});
  });

  test('the new types are registered with sensible defaults', () {
    expect(registry[FieldTypes.number].defaultFormat, TextFormat.number);
    expect(registry[FieldTypes.email].defaultFormat, TextFormat.email);
    expect(registry[FieldTypes.phone].defaultFormat, TextFormat.phone);
    expect(registry[FieldTypes.listbox].allowsMultiSelect, isTrue);
    expect(registry[FieldTypes.listbox].acceptsOptions, isTrue);
  });
}
