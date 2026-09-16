import 'package:form_engine/form_engine.dart';
import 'package:test/test.dart';

FormFieldModel field(
  String name, {
  String type = FieldTypes.text,
  bool required = false,
  TextFormat format = TextFormat.none,
  FieldValidation validation = const FieldValidation(),
  VisibilityCondition? condition,
  Calculation? calculation,
  int? maxLength,
}) =>
    FormFieldModel(
      id: name,
      typeId: type,
      page: 1,
      rect: const FractionalRect(0, 0, 0.2, 0.05),
      name: name,
      required: required,
      format: format,
      validation: validation,
      condition: condition,
      calculation: calculation,
      maxLength: maxLength,
    );

void main() {
  group('conditional visibility', () {
    final runtime = FormRuntime(FormSchema(fields: [
      field('has_company'),
      field('company_name',
          condition: VisibilityCondition(parent: FieldRef('has_company'), value: 'yes')),
    ]));

    test('a dependent field is hidden until its parent matches', () {
      expect(runtime.visibleFields({'has_company': 'no'}).map((f) => f.name), ['has_company']);
    });

    test('and appears once it does', () {
      expect(runtime.visibleFields({'has_company': 'yes'}).map((f) => f.name),
          ['has_company', 'company_name']);
    });

    test('a condition naming a field that does not exist leaves the field visible', () {
      // Hiding it would make part of the form permanently unreachable over a typo.
      final r = FormRuntime(FormSchema(fields: [
        field('orphan', condition: VisibilityCondition(parent: FieldRef('ghost'), value: 'x')),
      ]));
      expect(r.visibleFields({}).map((f) => f.name), ['orphan']);
    });

    test('every operator behaves as written', () {
      bool check(ConditionOperator op, String parent, String value) =>
          VisibilityCondition(parent: const FieldRef('p'), operator: op, value: value)
              .isSatisfiedBy({'p': parent});

      expect(check(ConditionOperator.equals, 'a', 'a'), isTrue);
      expect(check(ConditionOperator.notEquals, 'a', 'b'), isTrue);
      expect(check(ConditionOperator.contains, 'Hello World', 'world'), isTrue);
      expect(check(ConditionOperator.isEmpty, '   ', ''), isTrue);
      expect(check(ConditionOperator.isNotEmpty, 'x', ''), isTrue);
      expect(check(ConditionOperator.greaterThan, '10', '5'), isTrue);
      expect(check(ConditionOperator.lessThan, '3', '5'), isTrue);
    });
  });

  group('calculations', () {
    test('sums the fields it references', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('a', format: TextFormat.number),
        field('b', format: TextFormat.number),
        field('total',
            calculation: Calculation(
                function: CalculationFunction.sum, fields: [FieldRef('a'), FieldRef('b')])),
      ]));
      expect(runtime.applyCalculations({'a': '2', 'b': '3'})['total'], '5');
    });

    test('supports average, product, min and max', () {
      num? run(CalculationFunction fn) =>
          Calculation(function: fn, fields: [FieldRef('a'), FieldRef('b'), FieldRef('c')])
              .evaluate({'a': '2', 'b': '4', 'c': '6'});

      expect(run(CalculationFunction.average), 4);
      expect(run(CalculationFunction.product), 48);
      expect(run(CalculationFunction.min), 2);
      expect(run(CalculationFunction.max), 6);
    });

    test('skips non-numeric entries instead of counting them as zero', () {
      // Counting a blank as 0 would make every PRODUCT zero.
      expect(
        Calculation(function: CalculationFunction.product, fields: [FieldRef('a'), FieldRef('b')])
            .evaluate({'a': '5', 'b': ''}),
        5,
      );
    });

    test('a calculation feeding another settles', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('a', format: TextFormat.number),
        field('subtotal',
            calculation: Calculation(function: CalculationFunction.sum, fields: [FieldRef('a')])),
        field('total',
            calculation:
                Calculation(function: CalculationFunction.sum, fields: [FieldRef('subtotal')])),
      ]));
      expect(runtime.applyCalculations({'a': '7'})['total'], '7');
    });

    test('a circular reference terminates rather than hanging', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('x', calculation: Calculation(fields: [FieldRef('y')])),
        field('y', calculation: Calculation(fields: [FieldRef('x')])),
      ]));
      expect(() => runtime.applyCalculations({'x': '1', 'y': '2'}), returnsNormally);
    });

    test('whole numbers do not gain a trailing decimal', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('a'),
        field('t', calculation: Calculation(fields: [FieldRef('a')])),
      ]));
      expect(runtime.applyCalculations({'a': '4'})['t'], '4');
    });
  });

  group('validation', () {
    test('required fields must be filled', () {
      final runtime = FormRuntime(FormSchema(fields: [field('name', required: true)]));
      expect(runtime.validate({'name': ''}).single.problem, ValidationProblem.required);
      expect(runtime.validate({'name': 'Vishnu'}), isEmpty);
    });

    test('a required field that is hidden is not demanded', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('has_company'),
        field('company_name',
            required: true,
            condition: VisibilityCondition(parent: FieldRef('has_company'), value: 'yes')),
      ]));
      expect(runtime.validate({'has_company': 'no'}), isEmpty);
      expect(runtime.validate({'has_company': 'yes'}).single.problem, ValidationProblem.required);
    });

    test('length bounds are enforced', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('pin', validation: const FieldValidation(minLength: 4, maxLength: 6)),
      ]));
      expect(runtime.validate({'pin': '12'}).single.problem, ValidationProblem.tooShort);
      expect(runtime.validate({'pin': '1234567'}).single.problem, ValidationProblem.tooLong);
      expect(runtime.validate({'pin': '12345'}), isEmpty);
    });

    test('the field maxLength also caps input when no rule is set', () {
      final runtime = FormRuntime(FormSchema(fields: [field('code', maxLength: 3)]));
      expect(runtime.validate({'code': 'abcd'}).single.problem, ValidationProblem.tooLong);
    });

    test('a regex pattern is applied', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('code', validation: const FieldValidation(pattern: r'^[A-Z]{3}$')),
      ]));
      expect(runtime.validate({'code': 'abc'}).single.problem, ValidationProblem.pattern);
      expect(runtime.validate({'code': 'ABC'}), isEmpty);
    });

    test('numbers are checked and bounded', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('age',
            format: TextFormat.number,
            validation: const FieldValidation(min: 18, max: 100)),
      ]));
      expect(runtime.validate({'age': 'abc'}).single.problem, ValidationProblem.notANumber);
      expect(runtime.validate({'age': '12'}).single.problem, ValidationProblem.belowMinimum);
      expect(runtime.validate({'age': '120'}).single.problem, ValidationProblem.aboveMaximum);
      expect(runtime.validate({'age': '30'}), isEmpty);
    });

    test('email format is checked loosely', () {
      final runtime = FormRuntime(FormSchema(fields: [field('mail', format: TextFormat.email)]));
      expect(runtime.validate({'mail': 'nope'}).single.problem, ValidationProblem.notAnEmail);
      expect(runtime.validate({'mail': 'a.b+c@example.co.in'}), isEmpty);
    });

    test('an untouched optional field raises nothing', () {
      final runtime = FormRuntime(FormSchema(fields: [
        field('mail', format: TextFormat.email, validation: const FieldValidation(minLength: 5)),
      ]));
      expect(runtime.validate({'mail': ''}), isEmpty);
    });
  });
}
