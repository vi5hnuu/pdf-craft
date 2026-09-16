import 'package:form_engine/form_engine.dart';
import 'package:test/test.dart';

/// These cover the reason rules moved from names to ids.
///
/// With name-based references, renaming a field silently changed what its dependants
/// computed — a verified total went from 5 to 3 with no error raised — and two fields could
/// share a name with nothing to stop them.
void main() {
  const codec = SchemaCodec();

  FormFieldModel num_(String id, String name, {Calculation? calc}) => FormFieldModel(
        id: id,
        typeId: FieldTypes.number,
        page: 1,
        rect: const FractionalRect(0, 0, 0.2, 0.05),
        name: name,
        calculation: calc,
      );

  test('renaming a field does not break a calculation that depends on it', () {
    final schema = FormSchema(fields: [
      num_('f1', 'amount_a'),
      num_('f2', 'amount_b'),
      num_('f3', 'total',
          calc: const Calculation(fields: [FieldRef('f1'), FieldRef('f2')])),
    ]);

    expect(FormRuntime(schema).applyCalculations({'f1': '2', 'f2': '3'})['f3'], '5');

    schema.fields[0].name = 'subtotal_a'; // the author renames it in the inspector
    expect(FormRuntime(schema).applyCalculations({'f1': '2', 'f2': '3'})['f3'], '5',
        reason: 'the rule points at the id, which the rename did not touch');
  });

  test('renaming a field does not break a condition that depends on it', () {
    final schema = FormSchema(fields: [
      num_('f1', 'country'),
      FormFieldModel(
        id: 'f2',
        typeId: FieldTypes.text,
        page: 1,
        rect: const FractionalRect(0, 0.1, 0.2, 0.05),
        name: 'gst',
        condition: const VisibilityCondition(parent: FieldRef('f1'), value: 'India'),
      ),
    ]);

    expect(FormRuntime(schema).visibleFields({'f1': 'India'}).length, 2);
    schema.fields[0].name = 'country_of_residence';
    expect(FormRuntime(schema).visibleFields({'f1': 'India'}).length, 2);
    expect(FormRuntime(schema).visibleFields({'f1': 'UK'}).length, 1);
  });

  group('integrity', () {
    test('a calculation pointing at a deleted field is reported', () {
      final schema = FormSchema(fields: [
        num_('f3', 'total', calc: const Calculation(fields: [FieldRef('gone')])),
      ]);
      final issues = FormRuntime(schema).integrityIssues();
      expect(issues.single.problem, SchemaProblem.danglingCalculation);
      expect(issues.single.target, 'gone');
    });

    test('a condition pointing at a deleted field is reported', () {
      final schema = FormSchema(fields: [
        FormFieldModel(
          id: 'f1',
          typeId: FieldTypes.text,
          page: 1,
          rect: const FractionalRect(0, 0, 0.2, 0.05),
          name: 'x',
          condition: const VisibilityCondition(parent: FieldRef('missing')),
        ),
      ]);
      expect(FormRuntime(schema).integrityIssues().single.problem,
          SchemaProblem.danglingCondition);
    });

    test('a field calculating from itself is reported', () {
      final schema = FormSchema(fields: [
        num_('f1', 'loop', calc: const Calculation(fields: [FieldRef('f1')])),
      ]);
      expect(FormRuntime(schema).integrityIssues().any((i) => i.problem == SchemaProblem.selfReference),
          isTrue);
    });

    test('two fields sharing a name are reported', () {
      // They would collapse into one field in the PDF, so one value silently wins.
      final schema = FormSchema(fields: [num_('f1', 'amount'), num_('f2', 'amount')]);
      final issues = FormRuntime(schema).integrityIssues();
      expect(issues.single.problem, SchemaProblem.duplicateName);
      expect(issues.single.target, 'amount');
    });

    test('a healthy form reports nothing', () {
      final schema = FormSchema(fields: [
        num_('f1', 'a'),
        num_('f2', 'total', calc: const Calculation(fields: [FieldRef('f1')])),
      ]);
      expect(FormRuntime(schema).integrityIssues(), isEmpty);
    });
  });

  group('v1 -> v2 migration', () {
    Map<String, Object?> v1Draft() => {
          'version': 1,
          'page_sizes': {
            '1': {'width': 595.0, 'height': 842.0}
          },
          'fields': [
            {
              'id': 'f1',
              'type': 'number',
              'page': 1,
              'rect': {'left': 0.0, 'top': 0.0, 'width': 0.2, 'height': 0.05},
              'name': 'amount_a'
            },
            {
              'id': 'f2',
              'type': 'number',
              'page': 1,
              'rect': {'left': 0.0, 'top': 0.1, 'width': 0.2, 'height': 0.05},
              'name': 'total',
              // v1 spelling: names, not ids
              'calculation': {'function': 'sum', 'fields': ['amount_a']},
              'condition': {'parent_field': 'amount_a', 'operator': 'isNotEmpty', 'value': ''}
            },
          ],
        };

    test('old name-based rules are rewritten to ids', () {
      final schema = codec.decode(v1Draft());
      final total = schema.fields[1];
      expect(total.calculation!.fields.single.id, 'f1');
      expect(total.condition!.parent.id, 'f1');
      expect(schema.version, FormSchema.currentVersion);
    });

    test('the migrated rules still work', () {
      final schema = codec.decode(v1Draft());
      expect(FormRuntime(schema).applyCalculations({'f1': '9'})['f2'], '9');
    });

    test('a v1 rule naming a field that never existed is kept, not dropped', () {
      final draft = v1Draft();
      ((draft['fields'] as List)[1] as Map)['calculation'] = {
        'function': 'sum',
        'fields': ['ghost']
      };
      final schema = codec.decode(draft);
      expect(schema.fields[1].calculation!.fields.single.id, 'ghost');
      expect(FormRuntime(schema).integrityIssues().single.problem,
          SchemaProblem.danglingCalculation,
          reason: 'it was already broken; surfacing it beats hiding it');
    });
  });

  test('document metadata round-trips', () {
    final schema = FormSchema(
      documentId: 'doc-1',
      title: 'Invoice',
      updatedAt: DateTime.utc(2026, 9, 16, 12),
      recipients: const [Recipient(id: 'r1', name: 'Signer', order: 1)],
      fields: [num_('f1', 'a')],
    );
    final decoded = codec.decode(codec.encode(schema));
    expect(decoded.documentId, 'doc-1');
    expect(decoded.title, 'Invoice');
    expect(decoded.updatedAt, DateTime.utc(2026, 9, 16, 12));
    expect(decoded.recipients.single.name, 'Signer');
  });
}
