import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/pages/annotate/annotation.dart';

/// The annotation model's two load-bearing rules: geometry is page fractions, and a snapshot
/// keeps its identity.
void main() {
  InkAnnotation ink() => InkAnnotation(
        page: 0,
        color: const Color(0xFFFF0000),
        points: const [Offset(0.1, 0.1), Offset(0.5, 0.5)],
        strokeWidth: 0.004,
      );

  group('identity', () {
    test('copy keeps the id, because undo snapshots the same mark at an earlier moment', () {
      // Minting a new id here is invisible until you undo: the selection stops matching, and an
      // inserted image loses its entry in the decoded-image cache, which is keyed by id.
      final a = ink();
      expect(a.copy().id, a.id);
    });

    test('duplicate mints a new id, because it is a genuinely new mark', () {
      final a = ink();
      expect(a.duplicate().id, isNot(a.id));
    });

    test('a copy does not share mutable state with its original', () {
      final a = ink();
      final b = a.copy() as InkAnnotation;
      b.points.add(const Offset(0.9, 0.9));
      expect(a.points.length, 2, reason: 'undoing would have mutated the live mark');
    });
  });

  group('geometry', () {
    test('a stroke moved by its bounds keeps its shape rather than being refitted', () {
      final a = InkAnnotation(
        page: 0,
        color: const Color(0xFF000000),
        points: const [Offset(0.1, 0.1), Offset(0.3, 0.1), Offset(0.2, 0.3)],
        strokeWidth: 0.004,
      );
      final before = a.bounds;
      a.bounds = before.translate(0.2, 0.1);

      void expectPoint(Offset actual, double dx, double dy) {
        expect(actual.dx, closeTo(dx, 1e-9));
        expect(actual.dy, closeTo(dy, 1e-9));
      }

      expectPoint(a.points[0], 0.3, 0.2);
      expectPoint(a.points[1], 0.5, 0.2);
      expectPoint(a.points[2], 0.4, 0.4);
      expect(a.bounds.width, closeTo(before.width, 1e-9));
      expect(a.bounds.height, closeTo(before.height, 1e-9));
    });

    test('an arrow resized by its bounds keeps which end is which', () {
      final a = LineAnnotation(
        page: 0,
        color: const Color(0xFF000000),
        from: const Offset(0.1, 0.1),
        to: const Offset(0.5, 0.5),
        strokeWidth: 0.003,
        arrow: true,
      );
      a.bounds = const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);

      expect(a.from.dx, closeTo(0.1, 1e-9), reason: 'the tail moved to the head');
      expect(a.from.dy, closeTo(0.1, 1e-9));
      expect(a.to.dx, closeTo(0.9, 1e-9));
      expect(a.to.dy, closeTo(0.9, 1e-9));
    });
  });

  group('wire format', () {
    test('a colour goes as #RRGGBB with opacity carried separately', () {
      // A PDF annotation keeps its transparency in /CA, not in the colour, so packing alpha into
      // the hex would set it twice and get it wrong.
      final a = ink()..opacity = 0.4;
      final wire = a.toWire();

      expect(wire['color'], '#ff0000');
      expect(wire['opacity'], 0.4);
      expect(wire['type'], 'ink');
      expect(wire['points'], [
        [0.1, 0.1],
        [0.5, 0.5]
      ]);
    });

    test('a highlighter is a different wire type from a pen, not a translucent pen', () {
      final pen = ink();
      final marker = InkAnnotation(
        page: 0,
        color: const Color(0xFFFFEB3B),
        points: const [Offset(0.1, 0.5)],
        strokeWidth: 0.016,
        highlighter: true,
      );
      expect(pen.toWire()['type'], 'ink');
      expect(marker.toWire()['type'], 'highlight');
    });

    test('an image is not sent as a pdf annotation', () {
      // There is no markup annotation that means "this bitmap"; images go via the stamp endpoint.
      final img = ImageAnnotation(
        page: 0,
        bounds: const Rect.fromLTWH(0.1, 0.1, 0.3, 0.2),
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(img.isPdfAnnotation, isFalse);
      expect(ink().isPdfAnnotation, isTrue);
    });

    test('a rect is sent as left, top, width, height in page fractions', () {
      final s = ShapeAnnotation(
        page: 2,
        color: const Color(0xFF0000FF),
        bounds: const Rect.fromLTWH(0.2, 0.3, 0.4, 0.1),
        strokeWidth: 0.003,
        ellipse: false,
      );
      final rect = s.toWire()['rect'] as List;
      expect(rect[0], closeTo(0.2, 1e-9));
      expect(rect[1], closeTo(0.3, 1e-9));
      expect(rect[2], closeTo(0.4, 1e-9));
      expect(rect[3], closeTo(0.1, 1e-9));
      expect(s.toWire()['page'], 2);
      expect(s.toWire()['type'], 'square');
    });
  });
}
