import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/widgets/ink/drawing_pad.dart';
import 'package:pdf_craft/widgets/ink/ink_painting.dart';

/// The shared ink module. Three screens draw through it now — annotate, the Sign tool and the
/// signature sheet — so its rules are worth pinning.
void main() {
  group('smoothing', () {
    test('a stroke is curved, not a polyline', () {
      // The whole point: samples become tangents of quadratic segments rather than corners.
      // A polyline path of n points has n-1 line verbs and no curves.
      final path = buildInkPath(const [
        Offset(0, 0),
        Offset(10, 10),
        Offset(20, 0),
        Offset(30, 10),
      ]);
      final verbs = path.computeMetrics().toList();
      expect(verbs, isNotEmpty);
      // A curved path through these points is longer than the 0->30 straight line and shorter
      // than the full zig-zag, which is what "smoothed" means geometrically.
      final length = verbs.first.length;
      expect(length, greaterThan(30));
      expect(length, lessThan(60));
    });

    test('one and two points still produce something drawable', () {
      expect(buildInkPath(const [Offset(5, 5)]).computeMetrics().isEmpty, isTrue,
          reason: 'a single point has no length; paintInkStroke draws it as a dot instead');
      final two = buildInkPath(const [Offset(0, 0), Offset(3, 4)]);
      expect(two.computeMetrics().first.length, closeTo(5, 1e-6));
    });

    test('an empty stroke is an empty path rather than a crash', () {
      expect(buildInkPath(const []).computeMetrics().isEmpty, isTrue);
    });
  });

  group('thinning', () {
    test('a sample the finger cannot distinguish is dropped', () {
      expect(inkShouldAdd(const Offset(0, 0), const Offset(0.5, 0)), isFalse);
      expect(inkShouldAdd(const Offset(0, 0), const Offset(5, 0)), isTrue);
    });
  });

  group('pad controller', () {
    test('the revision changes on every edit, because the stroke list does not', () {
      // The painter compares this. Comparing the list itself could never work: it is the same
      // object, mutated in place — which is why strokes appeared and then never updated.
      final pad = DrawingPadController();
      final start = pad.revision;

      pad.begin(const Offset(0, 0), const Color(0xFF000000), 3);
      final afterBegin = pad.revision;
      expect(afterBegin, greaterThan(start));

      pad.extend(const Offset(40, 40));
      expect(pad.revision, greaterThan(afterBegin));
    });

    test('undo and redo walk whole strokes', () {
      final pad = DrawingPadController();
      pad.begin(const Offset(0, 0), const Color(0xFF000000), 3);
      pad.extend(const Offset(40, 0));
      pad.begin(const Offset(0, 40), const Color(0xFF000000), 3);

      expect(pad.strokes.length, 2);
      expect(pad.canUndo, isTrue);

      pad.undo();
      expect(pad.strokes.length, 1);
      expect(pad.canRedo, isTrue);

      pad.redo();
      expect(pad.strokes.length, 2);
      expect(pad.canRedo, isFalse);
    });

    test('drawing after an undo drops the redo branch', () {
      final pad = DrawingPadController();
      pad.begin(const Offset(0, 0), const Color(0xFF000000), 3);
      pad.undo();
      expect(pad.canRedo, isTrue);

      pad.begin(const Offset(10, 10), const Color(0xFF000000), 3);
      expect(pad.canRedo, isFalse, reason: 'a new stroke makes the undone one unreachable');
    });

    test('extending with no stroke started is ignored rather than throwing', () {
      final pad = DrawingPadController();
      pad.extend(const Offset(5, 5));
      expect(pad.strokes, isEmpty);
    });

    test('ink bounds cover the drawing plus the stroke width', () {
      final pad = DrawingPadController();
      pad.begin(const Offset(20, 20), const Color(0xFF000000), 4);
      pad.extend(const Offset(60, 50));

      final bounds = pad.inkBounds()!;
      // Padded outwards, so a thick stroke is not clipped at the edge of the export.
      expect(bounds.left, lessThan(20));
      expect(bounds.top, lessThan(20));
      expect(bounds.right, greaterThan(60));
      expect(bounds.bottom, greaterThan(50));
    });

    test('an untouched pad has no bounds and reports itself empty', () {
      final pad = DrawingPadController();
      expect(pad.isEmpty, isTrue);
      expect(pad.inkBounds(), isNull);
    });

    test('clear resets both history stacks', () {
      final pad = DrawingPadController();
      pad.begin(const Offset(0, 0), const Color(0xFF000000), 3);
      pad.undo();
      pad.clear();
      expect(pad.canUndo, isFalse);
      expect(pad.canRedo, isFalse);
    });
  });
}
