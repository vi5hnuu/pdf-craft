import 'package:in_app_review/in_app_review.dart';
import 'package:pdf_craft/singletons/app_config_service.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Decides when to ask for a store rating, and asks through Google's own flow.
///
/// The trigger is a tool finishing successfully — the earned moment — but that alone is not
/// enough. Asking someone to rate the app right after something of theirs failed, or right after
/// being asked to pay, is how an app collects one-star reviews. Each guard below prevents one of
/// those, and the thresholds come from the server so they can be retuned without a release.
///
/// Google's In-App Review API decides for itself whether to show anything and quotas it per user,
/// so "asked" only ever means "we requested it". Nothing waits on a dialog or assumes one
/// appeared — which is also why the old count-only rule is gone: with no callback to tell us the
/// user rated, a cool-off is the only honest way to avoid nagging.
class RateAppService {
  static final RateAppService _instance = RateAppService._();

  RateAppService._();

  factory RateAppService() => _instance;

  static const _countKey = 'tool_success_count';
  static const _firstSuccessKey = 'rate_first_success_ms';
  static const _lastAskKey = 'rate_last_ask_ms';

  final InAppReview _review = InAppReview.instance;

  /// Set when anything fails during this run of the app, and never cleared: one failure is
  /// enough to make the whole session the wrong moment to ask.
  bool _sessionHadError = false;

  /// When the user was last shown a paywall, an ad, or charged credits.
  DateTime? _lastMonetisation;

  /// Call when a tool fails, so nothing asks for a rating this session.
  void noteError() => _sessionHadError = true;

  /// Call on a paywall, an ad, or a credit charge, so a rating is not asked for in its shadow.
  void noteMonetisation() => _lastMonetisation = DateTime.now();

  /// Records a successful tool run and requests a review if every guard allows it.
  ///
  /// Never throws: a tool finishing is the caller's business and this is a side errand.
  Future<void> recordSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final count = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, count);

      // First success stands in for "has used the app for a while"; it needs no bookkeeping
      // anywhere else and cannot be faked by reinstalling any more easily than install date.
      final firstMs = prefs.getInt(_firstSuccessKey) ??
          await _remember(prefs, _firstSuccessKey, now);

      if (!shouldAsk(
        successes: count,
        firstSuccess: DateTime.fromMillisecondsSinceEpoch(firstMs),
        lastAskMs: prefs.getInt(_lastAskKey),
        now: now,
      )) {
        return;
      }

      if (!await _review.isAvailable()) return;
      // Written before the request, not after: if it throws, the cool-off should still apply,
      // or a persistent failure would retry on every single success.
      await prefs.setInt(_lastAskKey, now.millisecondsSinceEpoch);
      await _review.requestReview();
    } catch (e) {
      LoggerSingleton().logger.w('Rating prompt skipped: $e');
    }
  }

  /// Every guard, in one place and free of I/O so it can be tested directly.
  ///
  /// Visible for tests: the decision is the whole feature, and it is worth pinning without
  /// needing a device, a store or a clock.
  bool shouldAsk({
    required int successes,
    required DateTime firstSuccess,
    int? lastAskMs,
    required DateTime now,
  }) {
    final config = AppConfigService().config;

    // Something broke for this user this session. Whatever else is true, this is not the moment.
    if (_sessionHadError) return false;

    // Straight after a paywall, an ad or a charge, "please rate us" reads as "pay us, now
    // praise us".
    final monetised = _lastMonetisation;
    if (monetised != null && now.difference(monetised) < const Duration(minutes: 5)) {
      return false;
    }

    if (successes < config.ratingMinSuccesses) return false;
    if (now.difference(firstSuccess) < Duration(days: config.ratingMinDaysInstalled)) {
      return false;
    }

    if (lastAskMs != null) {
      final lastAsk = DateTime.fromMillisecondsSinceEpoch(lastAskMs);
      if (now.difference(lastAsk) < Duration(days: config.ratingMinDaysBetweenAsks)) {
        return false;
      }
    }
    return true;
  }

  Future<int> _remember(SharedPreferences prefs, String key, DateTime now) async {
    await prefs.setInt(key, now.millisecondsSinceEpoch);
    return now.millisecondsSinceEpoch;
  }

  /// Opens the store listing. For the explicit "Rate this app" row in Settings, where the user
  /// asked to go there — unlike the automatic prompt, which stays in the app.
  Future<void> openPlayStore() async {
    final url = AppConfigService().config.storeUrl?.trim();
    final uri = Uri.parse((url != null && url.isNotEmpty)
        ? url
        : 'https://play.google.com/store/apps/details?id=${Constants.androidPackageName}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
