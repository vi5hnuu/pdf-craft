import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/tools/tool_registry.dart';

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

  test('every tool in the registry has a translated name and description', () {
    // Keys follow toolName<Id> / toolDesc<Id>, e.g. 'pdf-to-jpg' -> toolNamePdfToJpg.
    String camel(String id) {
      final parts = id.split(RegExp(r'[-_ ]+'));
      return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
    }
    String key(String prefix, String id) {
      final c = camel(id);
      return '$prefix${c[0].toUpperCase()}${c.substring(1)}';
    }

    final missing = <String>[];
    for (final tool in ToolRegistry.tools) {
      for (final k in [key('toolName', tool.id), key('toolDesc', tool.id)]) {
        if (!en.containsKey(k) || !hi.containsKey(k)) missing.add(k);
      }
      if (ToolStrings.englishName(tool.id) == tool.id) missing.add('englishName:${tool.id}');
    }
    expect(missing, isEmpty);
  });

  test('every tool category has a translated name', () {
    // 'PDF Tools' -> toolCatPdfTools
    String categoryKey(String englishName) {
      final parts = englishName.toLowerCase().split(RegExp(r'\s+'));
      final camel =
          parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
      return 'toolCat${camel[0].toUpperCase()}${camel.substring(1)}';
    }

    for (final category in ToolCategories.all) {
      final k = categoryKey(category.name);
      expect(en.containsKey(k), isTrue, reason: 'missing $k in English');
      expect(hi.containsKey(k), isTrue, reason: 'missing $k in Hindi');
    }
  });

  test('no empty translations', () {
    for (final key in keys(hi)) {
      expect((hi[key] as String).trim(), isNotEmpty, reason: '"$key" is empty in Hindi');
    }
  });
}
