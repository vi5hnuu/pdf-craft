import 'dart:io';

import 'package:test/test.dart';

/// Asserts the `create-form` request keys the mapper emits all exist on the backend DTO.
///
/// `min_length` was offered in the editor, stored in the draft, enforced by the runtime and
/// never put on the wire. `condition` went the other way: the app sent it and nothing on the
/// server read it. Both were invisible because each side was only ever checked against itself —
/// the Dart golden test locks the shape the mapper produces, and nothing compared that shape to
/// what `FormFieldSpec` can receive.
///
/// Reads the Java source rather than running it, so it costs nothing and fails in `dart test`
/// the moment the two drift. Skipped when the backend is not checked out beside the app.
void main() {
  const dtoPath = 'src/main/java/com/vishnu/pdf_studio_api/pdfstudioapi/dto/request/'
      'CreateFormRequest.java';
  // The API is a sibling checkout, not a dependency, so its location varies by machine.
  // PDF_STUDIO_API_HOME wins; otherwise the two layouts it is actually kept in are tried.
  final home = Platform.environment['HOME'] ?? '';
  final roots = [
    Platform.environment['PDF_STUDIO_API_HOME'],
    '${Directory.current.path}/../../../pdf-studio-api',
    '$home/IdeaProjects/pdf-studio-api',
  ].whereType<String>();
  final dto = roots
      .map((root) => File('$root/$dtoPath'))
      .firstWhere((f) => f.existsSync(), orElse: () => File(dtoPath));

  test('every key the mapper sends is a field on FormFieldSpec', () {
    final mapper = File('${Directory.current.path}/lib/src/serialization/acroform_spec.dart')
        .readAsStringSync();
    final java = dto.readAsStringSync();

    // Field names on the DTO, which Jackson matches against snake_case keys.
    final declared = RegExp(r'private\s+[\w<>, ?]+\s+(\w+);')
        .allMatches(java)
        .map((m) => _snake(m.group(1)!))
        .toSet();

    // Keys the mapper writes: 'some_key': ...
    final sent = RegExp(r"'([a-z][a-z0-9_]*)':")
        .allMatches(mapper)
        .map((m) => m.group(1)!)
        .toSet();

    // Nested objects carry their own keys, checked against the inner classes by name above.
    final missing = sent.difference(declared);
    expect(missing, isEmpty,
        reason: 'the API has no field for: ${missing.join(', ')}');
  }, skip: dto.existsSync() ? null : 'backend not checked out beside the app');
}

String _snake(String camel) => camel
    .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
    .replaceFirst(RegExp(r'^_'), '');
