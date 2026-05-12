import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages a persisted set of bookmarked/favorite PDF file paths.
class FavoritesService {
  static final FavoritesService _instance = FavoritesService._();
  FavoritesService._();
  factory FavoritesService() => _instance;

  static const _key = 'favorite_file_paths';

  Future<List<String>> _getPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_key) ?? []);
  }

  Future<void> _savePaths(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, paths);
  }

  Future<bool> isFavorite(String path) async {
    final paths = await _getPaths();
    return paths.contains(path);
  }

  Future<void> toggle(String path) async {
    final paths = await _getPaths();
    if (paths.contains(path)) {
      paths.remove(path);
    } else {
      paths.insert(0, path);
    }
    await _savePaths(paths);
  }

  /// Returns favorite files that still exist on disk.
  Future<List<File>> getFavorites() async {
    final paths = await _getPaths();
    final existing = <File>[];
    for (final p in paths) {
      final f = File(p);
      if (await f.exists()) existing.add(f);
    }
    return existing;
  }

  Future<void> removeFile(String path) async {
    final paths = await _getPaths();
    paths.remove(path);
    await _savePaths(paths);
  }
}
