import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/utils/page_range.dart';

/// Guards the case proven on device: Header/Footer on a 3-page document with From 99, To 2 was
/// sent as typed, returned 200, charged a credit, and gave back the original file untouched.
void main() {
  group('validatePageRange', () {
    test('accepts an ordinary range', () {
      expect(validatePageRange(from: '1', to: '3', pageCount: 3), isNull);
      expect(validatePageRange(from: '2', to: '2', pageCount: 3), isNull);
    });

    test('an empty field means the start or the end of the document', () {
      expect(validatePageRange(from: '', to: '', pageCount: 3), isNull);
      expect(validatePageRange(from: '2', to: '', pageCount: 3), isNull);
      expect(validatePageRange(from: '', to: '2', pageCount: 3), isNull);
    });

    test('refuses a first page past the end of the document', () {
      expect(validatePageRange(from: '99', to: '', pageCount: 3),
          PageRangeError.beyondDocument);
      expect(validatePageRange(from: '4', to: '', pageCount: 3),
          PageRangeError.beyondDocument);
    });

    test('refuses a last page before the first — the case that was charged for', () {
      expect(validatePageRange(from: '99', to: '2', pageCount: 3),
          PageRangeError.beyondDocument);
      expect(validatePageRange(from: '3', to: '2', pageCount: 3), PageRangeError.backwards);
    });

    test('a last page past the end reads as "to the end", not an error', () {
      expect(validatePageRange(from: '1', to: '99', pageCount: 3), isNull);
    });

    test('refuses what is not a page number', () {
      expect(validatePageRange(from: 'abc', to: '', pageCount: 3), PageRangeError.notANumber);
      expect(validatePageRange(from: '1', to: 'x', pageCount: 3), PageRangeError.notANumber);
      expect(validatePageRange(from: '0', to: '', pageCount: 3), PageRangeError.notANumber);
      expect(validatePageRange(from: '-2', to: '', pageCount: 3), PageRangeError.notANumber);
    });

    test('with an unknown page count only the ordering rule applies', () {
      // The count is 0 when the document could not be read. Guessing a limit would block
      // perfectly good input, so only what is knowable is enforced.
      expect(validatePageRange(from: '99', to: '', pageCount: 0), isNull);
      expect(validatePageRange(from: '3', to: '2', pageCount: 0), PageRangeError.backwards);
    });
  });

  group('resolvePageRange', () {
    test('converts to the 0-based indices the API takes', () {
      final r = resolvePageRange(from: '2', to: '3', pageCount: 3);
      expect(r.fromIndex, 1);
      expect(r.toIndex, 2);
    });

    test('an empty last page means "to the end"', () {
      expect(resolvePageRange(from: '2', to: '', pageCount: 3).toIndex, isNull);
    });

    test('an empty first page means the first page', () {
      expect(resolvePageRange(from: '', to: '', pageCount: 3).fromIndex, 0);
    });

    test('clamps a last page past the end down to the document', () {
      expect(resolvePageRange(from: '1', to: '99', pageCount: 3).toIndex, 2);
    });
  });

  group('validatePositions', () {
    test('accepts a list of real positions', () {
      expect(validatePositions(text: '1,2,3', pageCount: 3), isNull);
    });

    test('accepts one past the end, which means "append"', () {
      expect(validatePositions(text: '4', pageCount: 3), isNull);
    });

    test('refuses a position past that', () {
      expect(validatePositions(text: '99', pageCount: 3), PageRangeError.beyondDocument);
      expect(validatePositions(text: '2,99', pageCount: 3), PageRangeError.beyondDocument);
    });

    test('refuses a typo instead of dropping it', () {
      // "2, abc, 99" used to insert one blank and silently discard the other two requests.
      expect(validatePositions(text: '2,abc,99', pageCount: 3), PageRangeError.notANumber);
      expect(validatePositions(text: '0', pageCount: 3), PageRangeError.notANumber);
    });

    test('ignores stray separators and whitespace', () {
      expect(validatePositions(text: ' 1 , 2 , ', pageCount: 3), isNull);
    });

    test('an empty list is the caller\'s business, not an error here', () {
      expect(validatePositions(text: '', pageCount: 3), isNull);
    });
  });
}
