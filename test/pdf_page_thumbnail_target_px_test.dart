import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/widgets/pdf_page_thumbnail.dart';

/// Guards the thumbnail render size against the value that broke four screens.
///
/// Delete Pages, Extract Pages, Duplicate Pages and the page-range picker all pass
/// `width: double.infinity` to mean "fill the grid cell". That reached `ceil()`, which throws
/// `UnsupportedError` on a non-finite value, and the throw escaped part-way through the load —
/// after the "already loading" flag was set and with no way to clear it — so every cell showed
/// a spinner that never resolved and no page ever appeared.
void main() {
  group('thumbnailTargetPx', () {
    test('an infinite width yields the floor instead of throwing', () {
      expect(() => thumbnailTargetPx(double.infinity, 3.0), returnsNormally);
      expect(thumbnailTargetPx(double.infinity, 3.0), 64);
    });

    test('NaN and negative infinity are handled the same way', () {
      expect(thumbnailTargetPx(double.nan, 2.0), 64);
      expect(thumbnailTargetPx(double.negativeInfinity, 2.0), 64);
    });

    test('a zero or negative width yields the floor', () {
      expect(thumbnailTargetPx(0, 2.0), 64);
      expect(thumbnailTargetPx(-10, 2.0), 64);
    });

    test('a real width rounds up to the next 64px bucket', () {
      expect(thumbnailTargetPx(100, 2.0), 256); // 200 -> 256
      expect(thumbnailTargetPx(32, 2.0), 64); // 64 is already a bucket
      expect(thumbnailTargetPx(33, 2.0), 128); // 66 -> 128
    });

    test('near-identical widths share a bucket, so they share one render', () {
      expect(thumbnailTargetPx(101, 2.0), thumbnailTargetPx(110, 2.0));
    });

    test('a very large width is clamped rather than rasterising without bound', () {
      expect(thumbnailTargetPx(4000, 4.0), 2048);
    });
  });
}
