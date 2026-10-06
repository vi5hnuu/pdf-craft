import 'dart:io';

class Utility{
  static String bytesToSize(int bytes) {
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    if (bytes <= 0) return '0 B';

    // Determine which size suffix to use
    int i = (bytes > 0) ? (bytes.bitLength - 1) ~/ 10 : 0;
    double size = bytes / (1 << (i * 10));

    // Compared *after* rounding, which is where the fault was. 1048575 bytes is 1023.999 KB —
    // under the boundary, so the unit was right until toStringAsFixed(2) rounded it up and
    // printed "1024.00 KB", a quantity that should never appear. Checking the rounded value
    // catches exactly that case.
    if (double.parse(size.toStringAsFixed(2)) >= 1024 && i + 1 < sizes.length) {
      i += 1;
      size /= 1024;
    }

    // Format to 2 decimal places for readability
    return '${size.toStringAsFixed(2)} ${sizes[i]}';
  }

  static bool isPdf(String path) {
    // Case-insensitive so '.PDF' files also open in the in-app preview instead
    // of falling through to the external "open with" chooser.
    return path.toLowerCase().endsWith('.pdf');
  }

  static String fileName({required File file}) {
    return file.path.split('/').last;
  }

  /// The file's extension, lower-cased, or '' when it has none.
  ///
  /// Was `'.' + path.split('.').last`, which had three faults, all of them reaching the user:
  /// an upper-case name returned '.PDF' and every comparison in the app is against lower-case,
  /// so REPORT.PDF was greyed out in every tool's file picker and opened externally as */*
  /// instead of application/pdf; a file with no extension returned the whole path with a dot in
  /// front; and a dot in a *directory* name was mistaken for the extension.
  static String fileExtension(File file) {
    final path = file.path;
    final dot = path.lastIndexOf('.');
    // A dot before the last separator belongs to a directory, not to this file.
    if (dot <= 0 || dot < path.lastIndexOf('/')) return '';
    return path.substring(dot).toLowerCase();
  }
}
/// Redaction helpers for anything that leaves the device.
///
/// A file path is not neutral data: "/storage/emulated/0/Download/divorce-settlement.pdf"
/// discloses what the document is. Local logs can hold them, but crash reports are uploaded, so
/// anything that might reach one is reduced to its shape rather than its content.
abstract final class Redact {
  /// A path reduced to its extension and depth — enough to debug "the scan failed on a deep
  /// folder", never enough to learn what the file was.
  static String path(String? fullPath) {
    if (fullPath == null || fullPath.isEmpty) return '<none>';
    final segments = fullPath.split('/').where((s) => s.isNotEmpty).length;
    final dot = fullPath.lastIndexOf('.');
    final ext = dot > 0 && dot > fullPath.lastIndexOf('/')
        ? fullPath.substring(dot).toLowerCase()
        : '';
    return '<path depth=$segments ext=${ext.isEmpty ? 'none' : ext}>';
  }

  /// A filename reduced to its extension and length.
  static String fileName(String? name) {
    if (name == null || name.isEmpty) return '<none>';
    final dot = name.lastIndexOf('.');
    return '<file len=${name.length} ext=${dot > 0 ? name.substring(dot).toLowerCase() : 'none'}>';
  }
}
