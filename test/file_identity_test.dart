import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/utils/file_sort_filter.dart';
import 'package:pdf_craft/utils/utility.dart';

/// How the app decides what a file *is* — its extension, its size, its place in a listing.
///
/// These are the answers every tool picker, filter and type chip is built on, so a wrong one
/// does not stay local: it decides whether a file can be selected at all.
void main() {
  group('Utility.fileExtension', () {
    test('reads the extension of an ordinary path', () {
      expect(Utility.fileExtension(File('/storage/Download/report.pdf')), '.pdf');
    });

    test('is case-insensitive, like Utility.isPdf already is', () {
      // Scanners, Windows and some mail clients produce upper-case extensions. The picker
      // compares this against a tool's lower-case extension list, so a difference here is the
      // difference between a file the user can select and one greyed out for no stated reason.
      expect(Utility.isPdf('/storage/Download/REPORT.PDF'), isTrue,
          reason: 'isPdf already lowercases');
      expect(Utility.fileExtension(File('/storage/Download/REPORT.PDF')), '.pdf');
    });

    test('returns no extension for a file that has none, not the whole path', () {
      // `'/storage/README'.split('.').last` is the entire path, so the "extension" came back as
      // './storage/README'. ToolRegistry's own extension reader returns '' for this case.
      expect(Utility.fileExtension(File('/storage/README')), '');
    });

    test('uses the last dot, so a dotted directory does not confuse it', () {
      expect(Utility.fileExtension(File('/storage/my.files/report.pdf')), '.pdf');
      expect(Utility.fileExtension(File('/storage/my.files/README')), '');
    });
  });

  group('Utility.bytesToSize', () {
    test('formats within a unit', () {
      expect(Utility.bytesToSize(0), '0 B');
      expect(Utility.bytesToSize(512), '512.00 B');
      expect(Utility.bytesToSize(1024), '1.00 KB');
      expect(Utility.bytesToSize(1024 * 1024), '1.00 MB');
    });

    test('rolls over to the next unit instead of showing 1024 of the smaller one', () {
      // 1048575 is one byte under a megabyte. Picking the unit from bitLength alone lands on KB
      // and then rounds the value up to "1024.00 KB", a quantity that should never be printed.
      expect(Utility.bytesToSize(1024 * 1024 - 1), isNot(contains('1024.00')));
    });
  });

  group('applySortFilter', () {
    List<FileSystemEntity> entities() => [
          File('/root/banana.pdf'),
          Directory('/root/zeta-dir'),
          File('/root/Apple.PDF'),
          Directory('/root/alpha-dir'),
        ];

    test('sorts by name, case-insensitively, directories first', () {
      final out = applySortFilter(entities(),
          mode: FileSortMode.name, ascending: true);
      expect(out.map((e) => e.path.split('/').last).toList(),
          ['alpha-dir', 'zeta-dir', 'Apple.PDF', 'banana.pdf']);
    });

    test('the extension filter keeps directories so the user can still navigate', () {
      final out = applySortFilter(entities(),
          ext: '.pdf', mode: FileSortMode.name, ascending: true);
      expect(out.whereType<Directory>().length, 2);
      // ...and matches an upper-case extension, since it lowercases the path.
      expect(out.whereType<File>().length, 2);
    });

    test('dirsFirst: false actually stops forcing directories to the top', () {
      // Both branches of the `if (!dirsFirst)` return the same list, so the parameter does
      // nothing. Search passes dirsFirst: false and silently gets dirs-first behaviour.
      final out = applySortFilter(entities(),
          mode: FileSortMode.name, ascending: true, dirsFirst: false);
      expect(out.map((e) => e.path.split('/').last).toList(),
          ['alpha-dir', 'Apple.PDF', 'banana.pdf', 'zeta-dir'],
          reason: 'with dirsFirst false the listing should be one name-sorted sequence');
    });


    test('dirsFirst: false honours the chosen mode, not just name', () async {
      // The merged branch re-sorted by name whatever the mode was, so picking "Date" or "Size"
      // in Search quietly returned name order. Caught in review; the original test only
      // covered name mode, which is why it passed.
      final dir = await Directory.systemTemp.createTemp('sortmode');
      try {
        final big = File('${dir.path}/aaa-big.pdf')..writeAsStringSync('x' * 500);
        final small = File('${dir.path}/zzz-small.pdf')..writeAsStringSync('x');
        final bySize = applySortFilter([big, small],
            mode: FileSortMode.size, ascending: true, dirsFirst: false);
        expect(bySize.map((e) => e.path.split('/').last).toList(),
            ['zzz-small.pdf', 'aaa-big.pdf'],
            reason: 'smallest first — name order would have put aaa first');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('dirsFirst: true still groups directories above files', () {
      final out = applySortFilter(entities(),
          mode: FileSortMode.name, ascending: true, dirsFirst: true);
      expect(out.take(2).whereType<Directory>().length, 2);
    });

    test('the name filter is case-insensitive and matches a substring', () {
      final out = applySortFilter(entities(),
          nameQuery: 'APPLE', mode: FileSortMode.name, ascending: true);
      expect(out.map((e) => e.path.split('/').last).toList(), ['Apple.PDF']);
    });
  });

  group('availableExtensions', () {
    test('lowercases, and skips files with no extension', () {
      final exts = availableExtensions([
        File('/root/a.PDF'),
        File('/root/b.pdf'),
        File('/root/README'),
      ]);
      expect(exts, {'.pdf'});
    });
  });
}
