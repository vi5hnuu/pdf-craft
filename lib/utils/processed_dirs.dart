/// Where a tool's output can end up.
///
/// Normally public storage, so the file is visible to the user's other apps. When that is not
/// writable — permission revoked mid-session, or the write fails — the save falls back to the
/// app's own directory rather than discarding bytes the user has already paid for.
///
/// Both live here because the fallback is useless if the screens that list results do not know
/// about it: the first version of that fallback wrote somewhere no listing read, and told the
/// user to "open it from Results", where it could never appear.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf_craft/utils/constants.dart';

abstract final class ProcessedDirs {
  /// Public storage — where results belong when the app is allowed to put them there.
  static String get public => Constants.processedDirPath;

  /// The app's own directory. Needs no permission, and is cleared when the app is uninstalled.
  static Future<Directory> appPrivate() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/processed');

  /// Every directory a result may be in, newest-first scanning left to the caller. Only
  /// directories that exist are returned, so callers can list them without checking.
  static Future<List<Directory>> all() async {
    final dirs = <Directory>[];
    final pub = Directory(public);
    if (pub.existsSync()) dirs.add(pub);
    final priv = await appPrivate();
    if (priv.existsSync()) dirs.add(priv);
    return dirs;
  }
}
