import 'package:shared_preferences/shared_preferences.dart';

/// Central place for simple boolean preference flags, primarily the
/// "don't ask me again" toggles attached to confirmation dialogs.
///
/// Keeping the keys here (instead of scattering raw strings across screens)
/// avoids typos and makes it easy to see every persisted flag in one spot.
class PrefFlags {
  PrefFlags._();

  /// Skip the "what does uploading to Drive do?" explainer dialog.
  static const String skipDriveUploadInfo = 'flag_skip_drive_upload_info';

  /// Reads a flag; defaults to false (i.e. "still ask") when unset.
  static Future<bool> isSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  /// Persists a flag value.
  static Future<void> set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
