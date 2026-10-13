import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the bundled font faces in step with the weights the code actually asks for.
///
/// Runtime fetching is off (AppTheme.configure), so a weight with no bundled face does not
/// crash — google_fonts logs and Flutter falls back to Roboto for that one style. That is a
/// silent visual regression, which is exactly the kind nobody notices, so it is asserted here
/// instead. Both families must carry every weight, because Hind replaces Poppins wholesale
/// when the app is in Hindi.
void main() {
  /// FontWeight.wNNN -> the filename part google_fonts resolves a bundled face by.
  const weightToFace = <String, String>{
    'w100': 'Thin',
    'w200': 'ExtraLight',
    'w300': 'Light',
    'w400': 'Regular',
    'normal': 'Regular',
    'w500': 'Medium',
    'w600': 'SemiBold',
    'w700': 'Bold',
    'bold': 'Bold',
    'w800': 'ExtraBold',
    'w900': 'Black',
  };

  /// Weights Material's own TextTheme uses, which the root theme inherits even if no
  /// app code names them.
  const inheritedWeights = {'w400', 'w500'};

  const families = ['Poppins', 'Hind'];

  Set<String> weightsUsedInSource() {
    final used = <String>{...inheritedWeights};
    final pattern = RegExp(r'FontWeight\.(w\d{3}|bold|normal)');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/l10n/generated/')) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    return used;
  }

  test('every font weight the code uses has a bundled face in both families', () {
    final faces = weightsUsedInSource().map((w) {
      final face = weightToFace[w];
      expect(face, isNotNull, reason: 'unmapped FontWeight.$w');
      return face!;
    }).toSet();

    final missing = <String>[];
    for (final family in families) {
      for (final face in faces) {
        final path = 'assets/google_fonts/$family-$face.ttf';
        if (!File(path).existsSync()) missing.add(path);
      }
    }
    expect(missing, isEmpty,
        reason: 'the code uses these weights but the faces are not bundled: $missing');
  });

  test('no bundled face is unused', () {
    // The reverse direction, so a face nobody asks for does not keep costing APK size.
    final faces = weightsUsedInSource().map((w) => weightToFace[w]!).toSet();
    final unused = Directory('assets/google_fonts')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.ttf'))
        .where((n) => !faces.any((face) => n.endsWith('-$face.ttf')))
        .toList();
    expect(unused, isEmpty, reason: 'bundled but never requested: $unused');
  });
}
