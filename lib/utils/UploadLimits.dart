import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';

/// A selection that the server would reject for size, described for the user.
class UploadViolation {
  /// The offending file's name, or null when only the combined size is too large.
  final String? fileName;
  final int bytes;
  final int limit;

  const UploadViolation({this.fileName, required this.bytes, required this.limit});

  bool get isCombined => fileName == null;
}

/// Client-side mirror of the server's upload limits.
///
/// The server rejects oversized uploads, but only after the whole body has been sent — a 237 MB
/// PDF uploaded for minutes and then failed with a generic error, and the credit dialog had
/// already quoted a price. Checking before routing into a tool fails fast with a clear reason.
/// The server remains the authority; these limits only prevent a pointless upload.
class UploadLimits {
  UploadLimits._();

  /// Total size of [files] in bytes. Unreadable files count as 0 (the server will decide).
  static int totalBytes(List<File>? files) {
    if (files == null || files.isEmpty) return 0;
    var total = 0;
    for (final file in files) {
      total += _length(file);
    }
    return total;
  }

  static int _length(File file) {
    try {
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// Pure check over (name, size) pairs: the first file over the per-file limit, else the
  /// combined size over the per-request limit, else null.
  static UploadViolation? evaluate(
    List<MapEntry<String, int>> sizes, {
    int maxFileBytes = Constants.maxUploadFileBytes,
    int maxRequestBytes = Constants.maxUploadRequestBytes,
  }) {
    var total = 0;
    for (final entry in sizes) {
      if (entry.value > maxFileBytes) {
        return UploadViolation(fileName: entry.key, bytes: entry.value, limit: maxFileBytes);
      }
      total += entry.value;
    }
    if (total > maxRequestBytes) {
      return UploadViolation(bytes: total, limit: maxRequestBytes);
    }
    return null;
  }

  /// Returns true when [files] can be uploaded. Otherwise explains the limit in a dialog and
  /// returns false, so the caller stops before routing into the tool.
  static Future<bool> ensureWithinLimits(BuildContext context, List<File> files) async {
    final violation = evaluate([
      for (final f in files) MapEntry(f.path.split('/').last, _length(f)),
    ]);
    if (violation == null) return true;
    if (!context.mounted) return false;

    final size = Utility.bytesToSize(violation.bytes);
    final limit = Utility.bytesToSize(violation.limit);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 36),
        title: Text(L10n.of(ctx).uploadTooLargeTitle),
        content: Text(violation.isCombined
            ? L10n.of(ctx).uploadCombinedTooLarge(size, limit)
            : L10n.of(ctx).uploadFileTooLarge(violation.fileName!, size, limit)),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(ctx).ok)),
        ],
      ),
    );
    return false;
  }
}
