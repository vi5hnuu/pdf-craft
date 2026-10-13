import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/utils/constants.dart';

/// Keeps Constants.fileIcons honest against the files on disk and the pubspec.
///
/// The 'doc' entry pointed at an assets/file-types/doc.webp that was never added, and
/// Image.asset had no errorBuilder, so every .doc row in Files, Search and the picker painted
/// Flutter's grey exception box. Nothing caught it: a missing asset is a runtime failure, so
/// analyze and the widget tests were both clean.
void main() {
  const icons = Constants.fileIcons;

  test('every mapped file-type icon exists on disk', () {
    final missing = icons.entries
        .where((e) => !File(e.value).existsSync())
        .map((e) => '${e.key} -> ${e.value}')
        .toList();
    expect(missing, isEmpty, reason: 'mapped file-type icons with no asset: $missing');
  });

  test('no bundled file-type icon is left unreferenced', () {
    // The reverse direction, so a retired type does not quietly keep shipping its icon.
    final onDisk = Directory('assets/file-types')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    final referenced = icons.values.toSet();
    expect(onDisk.difference(referenced), isEmpty,
        reason: 'bundled icons nothing maps to: ${onDisk.difference(referenced)}');
  });
}
