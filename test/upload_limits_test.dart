import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/utils/UploadLimits.dart';

/// The client stops oversized uploads before they start; the rule must match the server's
/// per-file and per-request limits so nothing it would accept is blocked.
void main() {
  const mb = 1024 * 1024;

  UploadViolation? check(List<int> sizesMb) => UploadLimits.evaluate(
        [for (var i = 0; i < sizesMb.length; i++) MapEntry('f$i.pdf', sizesMb[i] * mb)],
        maxFileBytes: 50 * mb,
        maxRequestBytes: 100 * mb,
      );

  test('files within both limits pass', () {
    expect(check([10, 40]), isNull);
    expect(check([50]), isNull, reason: 'exactly at the limit is allowed');
  });

  test('a single file over the per-file limit is named', () {
    final v = check([10, 237]);
    expect(v, isNotNull);
    expect(v!.fileName, 'f1.pdf');
    expect(v.isCombined, isFalse);
  });

  test('files that each fit but exceed the request limit together are rejected as combined', () {
    final v = check([45, 45, 45]);
    expect(v, isNotNull);
    expect(v!.isCombined, isTrue);
    expect(v.bytes, 135 * mb);
  });

  test('no files means nothing to reject', () {
    expect(check([]), isNull);
  });
}
