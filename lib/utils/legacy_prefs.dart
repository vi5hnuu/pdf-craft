import 'package:shared_preferences/shared_preferences.dart';

/// Removes data that retired features left behind in [SharedPreferences].
///
/// A feature can be deleted from the code in one release, but whatever it already wrote stays
/// on every device that ran the old build until something removes it. For anything sensitive
/// that is not good enough — deleting the code only stops new writes.
abstract final class LegacyPrefs {
  /// Prefix of the per-file PDF password hints the protect tool used to save.
  ///
  /// The feature is gone: it weakened the protection the tool had just applied, it was keyed on
  /// the file's base name alone so an unrelated file of the same name showed someone else's
  /// hint, and nothing ever deleted it — not logout, not account deletion. Prefs are plain XML
  /// and readable on a rooted device, so a hint for a password is not something to keep there.
  static const String _passwordHintPrefix = 'pwd_hint_';

  /// Purges every retired key. Safe to call on every launch; it is a no-op once clean.
  static Future<void> purge() async {
    final prefs = await SharedPreferences.getInstance();
    final stale =
        prefs.getKeys().where((k) => k.startsWith(_passwordHintPrefix)).toList(growable: false);
    for (final key in stale) {
      await prefs.remove(key);
    }
  }
}
