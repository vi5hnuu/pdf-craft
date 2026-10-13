import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps one HttpStates key to one tool screen.
///
/// Five screens reached the reorder endpoint and all shared HttpStates.reorderPdf, which gave
/// two real races whenever one sat open beneath another — exactly what "use in another tool"
/// produces. A newly mounted screen's resetToolState wiped the other's in-flight `loading`,
/// taking its overlay and Cancel away while the request carried on and the credit was still
/// spent; and once both had dispatched, both consumed the single result: two previews, two
/// snackbars, two interstitials, two balance refreshes.
///
/// Asserted here because the failure is invisible until two particular screens are stacked,
/// which no amount of single-screen testing reaches.
void main() {
  test('no HttpStates key is read by more than one tool screen', () {
    final keyRef = RegExp(r'HttpStates\.([A-Za-z_][A-Za-z0-9_]*)');
    final screensByKey = <String, Set<String>>{};

    for (final entity in Directory('lib/pages').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Comments stripped first: a key named in prose — including a comment explaining why a
      // screen deliberately does *not* use one — is not a usage, and counting it would make
      // this test fail for documenting the very thing it checks.
      final source = entity
          .readAsStringSync()
          .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      // Only screens that actually run a tool; a screen that merely routes is not a consumer.
      if (!source.contains('runTool(')) continue;
      for (final m in keyRef.allMatches(source)) {
        screensByKey.putIfAbsent(m.group(1)!, () => <String>{}).add(entity.path);
      }
    }

    final shared = screensByKey.entries.where((e) => e.value.length > 1).map((e) {
      final names = e.value.map((p) => p.split('/').last).toList()..sort();
      return '${e.key} <- ${names.join(', ')}';
    }).toList()
      ..sort();

    expect(shared, isEmpty,
        reason: 'these HttpStates keys are read by more than one tool screen:\n'
            '${shared.join('\n')}');
  });
}
