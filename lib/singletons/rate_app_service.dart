import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tracks successful tool completions and prompts user to rate after N uses.
class RateAppService {
  static final RateAppService _instance = RateAppService._();
  RateAppService._();
  factory RateAppService() => _instance;

  static const _countKey  = 'tool_success_count';
  static const _ratedKey  = 'has_rated_app';
  static const _snoozeKey = 'rate_prompt_snoozed_until_count';
  static const _threshold = 5;  // show prompt after 5 successful tool uses
  static const _snoozeFor = 15; // ...and again this many uses later if they said "Later"
  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.vi5hnu.pdf_craft';

  /// Call this every time a tool completes successfully.
  /// Returns true if the rate-app dialog should be shown now.
  Future<bool> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_ratedKey) == true) return false;
    final count = (prefs.getInt(_countKey) ?? 0) + 1;
    await prefs.setInt(_countKey, count);

    final snoozedUntil = prefs.getInt(_snoozeKey);
    if (snoozedUntil != null) return count == snoozedUntil;
    return count == _threshold;
  }

  /// "Later": ask again after a further [_snoozeFor] successful uses.
  ///
  /// This used to call [markRated], so a single tap on "Later" silently opted the user out
  /// of ever being asked again — losing the rating from exactly the people still using the
  /// app enough to be asked.
  Future<void> snooze() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;
    await prefs.setInt(_snoozeKey, count + _snoozeFor);
  }

  /// Mark the user as having rated (or dismissed forever).
  Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ratedKey, true);
  }

  /// Opens the Play Store listing.
  Future<void> openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
