import 'dart:io';
import 'package:pdf_craft/utils/Constants.dart';

/// Returns recently modified PDF files by scanning device storage.
/// No SharedPreferences dependency — purely derived from filesystem timestamps.
class RecentFilesService {
  static final RecentFilesService _instance = RecentFilesService._();
  RecentFilesService._();
  factory RecentFilesService() => _instance;

  static const _dirsToScan = [
    Constants.processedDirPath,
    Constants.downloadsStoragePath,
    Constants.documentsStoragePath,
  ];

  /// Scans common directories and returns the [limit] most recently modified
  /// PDFs. Pass a large [limit] (e.g. from the "See more" screen) to get them
  /// all.
  ///
  /// Modified times are read once into a map before sorting so the comparator
  /// never performs sync IO repeatedly (O(N) stats instead of O(N log N)).
  Future<List<File>> getRecentFiles({int limit = 10}) async {
    final files = <File>[];
    final modTimes = <String, DateTime>{};
    for (final dirPath in _dirsToScan) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          files.add(entity);
          try {
            modTimes[entity.path] = entity.lastModifiedSync();
          } catch (_) {
            modTimes[entity.path] = DateTime(0);
          }
        }
      }
    }
    files.sort((a, b) => (modTimes[b.path] ?? DateTime(0))
        .compareTo(modTimes[a.path] ?? DateTime(0)));
    return files.take(limit).toList();
  }
}
