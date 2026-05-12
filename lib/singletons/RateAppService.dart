import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tracks successful tool completions and prompts user to rate after N uses.
class RateAppService {
  static final RateAppService _instance = RateAppService._();
  RateAppService._();
  factory RateAppService() => _instance;

  static const _countKey  = 'tool_success_count';
  static const _ratedKey  = 'has_rated_app';
  static const _threshold = 5; // show prompt after 5 successful tool uses
  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.vi5hnu.pdf_craft';

  /// Call this every time a tool completes successfully.
  /// Returns true if the rate-app dialog should be shown now.
  Future<bool> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_ratedKey) == true) return false;
    final count = (prefs.getInt(_countKey) ?? 0) + 1;
    await prefs.setInt(_countKey, count);
    return count == _threshold;
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
