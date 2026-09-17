import 'dart:io';

/// Sort field used by the Files browser and Search.
enum FileSortMode { name, date, size }

extension FileSortModeLabel on FileSortMode {
  String get label {
    switch (this) {
      case FileSortMode.name:
        return 'Name';
      case FileSortMode.date:
        return 'Date';
      case FileSortMode.size:
        return 'Size';
    }
  }
}

String _nameOf(FileSystemEntity e) => e.path.split('/').last;

/// Filters [files] by name substring + extension, then sorts by [mode] and
/// direction. Shared by the file browser and search so both behave identically.
///
/// Directories are kept above files (when [dirsFirst]) and are never hidden by
/// the extension filter (so the user can still navigate). Stats/lengths are
/// pre-cached before sorting so the comparator never performs sync IO
/// repeatedly (O(N) instead of O(N log N)).
List<FileSystemEntity> applySortFilter(
  List<FileSystemEntity> files, {
  String nameQuery = '',
  String? ext,
  required FileSortMode mode,
  required bool ascending,
  bool dirsFirst = true,
}) {
  Iterable<FileSystemEntity> filtered = files;

  final q = nameQuery.trim().toLowerCase();
  if (q.isNotEmpty) {
    filtered = filtered.where((f) => _nameOf(f).toLowerCase().contains(q));
  }
  if (ext != null) {
    filtered = filtered
        .where((f) => f is Directory || f.path.toLowerCase().endsWith(ext));
  }

  final dirs = filtered.whereType<Directory>().toList();
  final regularFiles = filtered.whereType<File>().toList();

  int byName(FileSystemEntity a, FileSystemEntity b) =>
      _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase());

  switch (mode) {
    case FileSortMode.name:
      dirs.sort(byName);
      regularFiles.sort(byName);
    case FileSortMode.date:
      final modTimes = <String, DateTime>{};
      for (final f in [...dirs, ...regularFiles]) {
        try {
          modTimes[f.path] = f.statSync().modified;
        } catch (_) {}
      }
      int byDate(FileSystemEntity a, FileSystemEntity b) =>
          (modTimes[a.path] ?? DateTime(0))
              .compareTo(modTimes[b.path] ?? DateTime(0));
      dirs.sort(byDate);
      regularFiles.sort(byDate);
    case FileSortMode.size:
      // Size is meaningless for directories, so they stay name-sorted.
      final sizes = <String, int>{};
      for (final f in regularFiles) {
        try {
          sizes[f.path] = f.lengthSync();
        } catch (_) {}
      }
      dirs.sort(byName);
      regularFiles.sort(
          (a, b) => (sizes[a.path] ?? 0).compareTo(sizes[b.path] ?? 0));
  }

  // Comparators above produce ascending order; flip for descending.
  final orderedDirs = ascending ? dirs : dirs.reversed.toList();
  final orderedFiles = ascending ? regularFiles : regularFiles.reversed.toList();

  if (!dirsFirst) {
    // Keep dirs/files interleaved by the chosen order is uncommon here; default
    // is dirs-first which both screens want.
    return [...orderedDirs, ...orderedFiles];
  }
  return [...orderedDirs, ...orderedFiles];
}

/// Distinct lowercase extensions among the regular files (for type filters).
Set<String> availableExtensions(List<FileSystemEntity> files) {
  final exts = <String>{};
  for (final f in files.whereType<File>()) {
    final dot = f.path.lastIndexOf('.');
    if (dot != -1) exts.add(f.path.substring(dot).toLowerCase());
  }
  return exts;
}
