import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every English string must have a Hindi translation (and vice versa), with the same
/// placeholders — otherwise Hindi users silently see English or a crash on a missing argument.
void main() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

  // Message keys only — skip "@@locale" and "@key" metadata entries.
  Set<String> keys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();

  final en = load('app_en.arb');
  final hi = load('app_hi.arb');

  test('Hindi has every English key', () {
    expect(keys(en).difference(keys(hi)), isEmpty);
  });

  test('Hindi has no keys missing from English', () {
    expect(keys(hi).difference(keys(en)), isEmpty);
  });

  test('placeholders match between languages', () {
    // A real placeholder is an identifier directly followed by `}` or `,` ("{count}",
    // "{count, plural"). Plural branch bodies like "=1{You have…" start with ordinary words and
    // must not be mistaken for placeholders.
    final placeholder = RegExp(r'\{([A-Za-z_]\w*)\s*[,}]');
    for (final key in keys(en)) {
      Set<String> names(String s) => placeholder.allMatches(s).map((m) => m.group(1)!).toSet();
      final enNames = names(en[key] as String);
      final hiNames = names(hi[key] as String);
      expect(hiNames.containsAll(enNames), isTrue, reason: 'placeholders differ for "$key"');
    }
  });

  test('no empty translations', () {
    for (final key in keys(hi)) {
      expect((hi[key] as String).trim(), isNotEmpty, reason: '"$key" is empty in Hindi');
    }
  });
}
