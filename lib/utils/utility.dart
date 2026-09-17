import 'dart:io';

class Utility{
  static String bytesToSize(int bytes) {
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    if (bytes <= 0) return '0 B';

    // Determine which size suffix to use
    int i = (bytes > 0) ? (bytes.bitLength - 1) ~/ 10 : 0;
    double size = bytes / (1 << (i * 10));

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

  static fileExtension(File file) {
    return '.${file.path.split('.').last}';
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
