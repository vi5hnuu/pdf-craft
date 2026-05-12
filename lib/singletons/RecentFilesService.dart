import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a list of recently opened PDF paths across app restarts.
class RecentFilesService {
  static final RecentFilesService _instance = RecentFilesService._();
  RecentFilesService._();
  factory RecentFilesService() => _instance;

  static const _key = 'recent_file_paths';
  static const _maxEntries = 15;

  /// Records a file as recently opened. Moves it to the front if already present.
  Future<void> addFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = List<String>.from(prefs.getStringList(_key) ?? []);
    paths.remove(path);
    paths.insert(0, path);
    if (paths.length > _maxEntries) paths.removeRange(_maxEntries, paths.length);
    await prefs.setStringList(_key, paths);
  }

  /// Returns recently opened files that still exist on disk (up to [limit]).
  Future<List<File>> getRecentFiles({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(_key) ?? [];
    final existing = <File>[];
    for (final p in paths) {
      final f = File(p);
      if (await f.exists()) existing.add(f);
      if (existing.length >= limit) break;
    }
    return existing;
  }

  /// Removes a path from the list (e.g. when file is deleted).
  Future<void> removeFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = List<String>.from(prefs.getStringList(_key) ?? []);
    paths.remove(path);
    await prefs.setStringList(_key, paths);
  }
}
