import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/utils/ReorderUtils.dart';

void main() {
  group('ReorderUtils.moveInPlace', () {
    test('moves an item later, using the index the item is dropped at', () {
      // onReorderItem reports the destination in the list with the item already lifted out,
      // so dragging A to sit after B is (from: 0, to: 1) — not the (0, 2) that the old
      // onReorder callback reported for the same gesture.
      final list = ['A', 'B', 'C', 'D'];
      ReorderUtils.moveInPlace(list, 0, 1);
      expect(list, ['B', 'A', 'C', 'D']);
    });

    test('moves an item to the end', () {
      final list = ['A', 'B', 'C'];
      ReorderUtils.moveInPlace(list, 0, 2);
      expect(list, ['B', 'C', 'A']);
    });

    test('moves an item earlier', () {
      final list = ['A', 'B', 'C', 'D'];
      ReorderUtils.moveInPlace(list, 3, 0);
      expect(list, ['D', 'A', 'B', 'C']);
    });

    test('a move onto itself leaves the order alone', () {
      final list = ['A', 'B', 'C'];
      ReorderUtils.moveInPlace(list, 1, 1);
      expect(list, ['A', 'B', 'C']);
    });

    test('an out-of-range source is ignored rather than throwing', () {
      final list = ['A', 'B'];
      ReorderUtils.moveInPlace(list, 5, 0);
      expect(list, ['A', 'B']);
    });

    test('a destination past the end lands at the end', () {
      final list = ['A', 'B', 'C'];
      ReorderUtils.moveInPlace(list, 0, 99);
      expect(list, ['B', 'C', 'A']);
    });
  });
}
