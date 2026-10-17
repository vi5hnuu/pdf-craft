import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stops a fixed grid column count coming back.
///
/// Five grids were pinned to three or two columns, so on a tablet each cell grew to a third or a
/// half of the window instead of more cells appearing. The max-cross-axis-extent delegates say
/// "a cell no wider than N" instead, and on a phone still yield the counts they replaced — but
/// nothing stops the next grid being written the old way, and the symptom only shows on hardware
/// most contributors are not testing on.
void main() {
  test('no grid hardcodes a cross-axis count', () {
    // n-up is the one legitimate case: the user picks how many PDF pages go on a sheet, which is
    // a document layout rather than a screen-size decision.
    const allowed = {'n_up_pdf_view.dart'};
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      if (allowed.contains(name)) continue;
      final source = entity
          .readAsStringSync()
          .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
      // A literal count, as opposed to one computed from the available width.
      for (final m in RegExp(r'crossAxisCount:\s*(\d+)').allMatches(source)) {
        offenders.add('${entity.path}: crossAxisCount: ${m.group(1)}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'use SliverGridDelegateWithMaxCrossAxisExtent / GridView.extent instead:\n'
            '${offenders.join('\n')}');
  });
}
