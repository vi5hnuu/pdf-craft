import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf_craft/singletons/file_store.dart';

/// Global, app-wide multi-file selection.
///
/// Selection used to live as local `setState` inside `DirectoryFilesListing`,
/// which reset every time the user navigated into another folder. Lifting it
/// into this singleton `ChangeNotifier` lets selections **persist across
/// folders** and lets any widget (file tiles, the selection action bar, the
/// tool intellisense menu) listen and stay in sync.
///
/// Files are kept unique by path and in insertion order.
class SelectionService extends ChangeNotifier {
  SelectionService._() {
    // Selections are keyed by path, and rename, move and delete all change paths. Without this
    // the selection went on pointing at files that no longer exist: the upload-size check reads
    // a missing file as 0 bytes and lets it through, so the failure surfaced much later, inside
    // the tool, as an upload of nothing.
    FileStore().addListener(_pruneMissing);
  }
  static final SelectionService _instance = SelectionService._();
  factory SelectionService() => _instance;

  final List<File> _files = [];

  /// Drops any selected file that has since disappeared from disk.
  void _pruneMissing() {
    final before = _files.length;
    _files.removeWhere((f) => !f.existsSync());
    if (_files.length != before) notifyListeners();
  }

  /// Currently selected files (unmodifiable view).
  List<File> get files => List.unmodifiable(_files);

  int get count => _files.length;

  /// Selection mode is "on" whenever at least one file is selected.
  bool get isActive => _files.isNotEmpty;

  bool contains(String path) => _files.any((f) => f.path == path);

  /// Adds [file] if not already selected.
  void add(File file) {
    if (contains(file.path)) return;
    _files.add(file);
    notifyListeners();
  }

  /// Removes the file at [path] if present.
  void removeByPath(String path) {
    final before = _files.length;
    _files.removeWhere((f) => f.path == path);
    if (_files.length != before) notifyListeners();
  }

  /// Toggles selection of [file].
  void toggle(File file) {
    if (contains(file.path)) {
      removeByPath(file.path);
    } else {
      add(file);
    }
  }

  /// Clears the whole selection (used by the "clear" action and after a tool
  /// consumes the selection).
  void clear() {
    if (_files.isEmpty) return;
    _files.clear();
    notifyListeners();
  }
}
