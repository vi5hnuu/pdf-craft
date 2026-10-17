import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/utils/responsive.dart';
import 'package:pdf_craft/widgets/tool_pane.dart';

void main() {
  group('windowSizeFor', () {
    test('classifies on the Material 3 thresholds, inclusive at the lower bound', () {
      expect(windowSizeFor(0), WindowSize.compact);
      expect(windowSizeFor(599.9), WindowSize.compact);
      expect(windowSizeFor(600), WindowSize.medium);
      expect(windowSizeFor(839.9), WindowSize.medium);
      expect(windowSizeFor(840), WindowSize.expanded);
      expect(windowSizeFor(2000), WindowSize.expanded);
    });

    test('atLeast reads as a threshold', () {
      expect(WindowSize.expanded.atLeast(WindowSize.medium), isTrue);
      expect(WindowSize.medium.atLeast(WindowSize.medium), isTrue);
      expect(WindowSize.compact.atLeast(WindowSize.medium), isFalse);
    });
  });

  group('ToolPane', () {
    /// Lays [pane] out in a box [width] wide and reports the child's painted width.
    Future<double> childWidth(WidgetTester tester, double width) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: 600,
            child: ToolPane(
              child: Container(key: const ValueKey('child'), color: Colors.red),
            ),
          ),
        ),
      ));
      return tester.getSize(find.byKey(const ValueKey('child'))).width;
    }

    testWidgets('passes the child through at phone width', (tester) async {
      expect(await childWidth(tester, 400), 400);
    });

    testWidgets('caps the child once there is more width than it should use', (tester) async {
      expect(await childWidth(tester, 1200), kMaxToolContentWidth);
    });

    testWidgets('does not cap below the content limit', (tester) async {
      // 700 is past the medium threshold but still under the readability limit, so the child
      // should fill it rather than being pinned to a narrower box.
      expect(await childWidth(tester, 700), 700);
    });
  });
}
