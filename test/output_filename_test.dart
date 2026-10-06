import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/utils/output_filename.dart';

/// The server names the file a tool produced. By the time that name is used the credit is
/// already spent, so a name the app cannot create costs the user the result they paid for.
void main() {
  group('filenameFromContentDisposition', () {
    test('reads the plain form, quoted or bare', () {
      expect(filenameFromContentDisposition('attachment; filename="merged.pdf"'), 'merged.pdf');
      expect(filenameFromContentDisposition('attachment; filename=merged.pdf'), 'merged.pdf');
    });

    test('prefers the extended form and percent-decodes it', () {
      expect(
        filenameFromContentDisposition("attachment; filename*=UTF-8''my%20report.pdf"),
        'my report.pdf',
      );
    });

    test('a malformed percent-escape does not throw', () {
      // Uri.decodeComponent throws FormatException on '%ZZ'. It used to escape this function,
      // the save, and the fallback save, so one bad header from a server or proxy destroyed a
      // result the user had been charged for.
      expect(
        () => filenameFromContentDisposition("attachment; filename*=UTF-8''%ZZbad.pdf"),
        returnsNormally,
      );
    });

    test('returns null when there is no filename to use', () {
      expect(filenameFromContentDisposition(null), isNull);
      expect(filenameFromContentDisposition(''), isNull);
      expect(filenameFromContentDisposition('attachment'), isNull);
    });

    test('a header naming a path writes inside the directory, not up out of it', () {
      expect(filenameFromContentDisposition(r'attachment; filename="../../secrets.pdf"'),
          'secrets.pdf');
      expect(filenameFromContentDisposition(r'attachment; filename="C:\Windows\evil.pdf"'),
          'evil.pdf');
    });

    test('names that survive stripping but are still directories are refused', () {
      // '/' leaves nothing, '.' and '..' leave a directory. All three used to come back as a
      // "filename", and writing bytes to a directory fails at the last possible moment.
      expect(filenameFromContentDisposition('attachment; filename="/"'), isNull);
      expect(filenameFromContentDisposition('attachment; filename="."'), isNull);
      expect(filenameFromContentDisposition('attachment; filename=".."'), isNull);
    });
  });

  group('sanitizeOutputName', () {
    test('keeps an ordinary name', () => expect(sanitizeOutputName('a.pdf'), 'a.pdf'));
    test('strips directories', () => expect(sanitizeOutputName('x/y/a.pdf'), 'a.pdf'));
    test('refuses what cannot be a file', () {
      expect(sanitizeOutputName(''), '');
      expect(sanitizeOutputName('   '), '');
      expect(sanitizeOutputName('.'), '');
      expect(sanitizeOutputName('..'), '');
      expect(sanitizeOutputName('/'), '');
    });
  });

  group('uniquePath', () {
    test('uses the name as-is when nothing is in the way', () {
      expect(uniquePath('/no/such/dir', 'out.pdf'), '/no/such/dir/out.pdf');
    });

    test('numbers a collision before the extension, not after it', () async {
      final dir = await Directory.systemTemp.createTemp('uniq');
      try {
        await File('${dir.path}/out.pdf').writeAsString('x');
        expect(uniquePath(dir.path, 'out.pdf'), '${dir.path}/out (1).pdf');
        await File('${dir.path}/out (1).pdf').writeAsString('x');
        expect(uniquePath(dir.path, 'out.pdf'), '${dir.path}/out (2).pdf');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('handles a name with no extension', () async {
      final dir = await Directory.systemTemp.createTemp('uniq');
      try {
        await File('${dir.path}/out').writeAsString('x');
        expect(uniquePath(dir.path, 'out'), '${dir.path}/out (1)');
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
