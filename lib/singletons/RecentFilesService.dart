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

  /// Scans common directories and returns the [limit] most recently modified PDFs.
  Future<List<File>> getRecentFiles({int limit = 10}) async {
    final files = <File>[];
    for (final dirPath in _dirsToScan) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          files.add(entity);
        }
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.take(limit).toList();
  }
}
