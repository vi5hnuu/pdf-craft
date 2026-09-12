import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/utils/AdUnits.dart';

/// Manages a single cached Rewarded ad, shown (opt-in) before "heavy" /
/// server-side operations so those expensive tools can stay free.
///
/// Mirrors [AppOpenAdManager]: load/cache, show, then preload the next.
class RewardedAdManager {
  /// Null when no production unit is configured, in which case nothing is loaded and the
  /// feature reports itself unavailable — the alternative, falling back to the test unit,
  /// serves Google's sample ads to real users and breaches the AdMob policy.
  static String? get _adUnitId => AdUnits.rewarded;

  RewardedAd? _cachedAd;
  bool _isLoading = false;

  static final RewardedAdManager _instance = RewardedAdManager._();
  RewardedAdManager._();
  factory RewardedAdManager() => _instance;

  bool get isReady => _cachedAd != null;

  /// Loads and caches a rewarded ad. No-ops while loading or already cached.
  /// Requires MobileAds to be initialized first.
  void loadAd() {
    if (_isLoading || _cachedAd != null) return;
    final adUnitId = _adUnitId;
    if (adUnitId == null) {
      LoggerSingleton().logger.w(
          'Rewarded ads disabled: no production ad unit is configured (AdUnits._prodRewarded).');
      return;
    }
    _isLoading = true;
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(keywords: [
        'pdf', 'document', 'compress', 'convert', 'merge', 'scanner'
      ]),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _cachedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          LoggerSingleton().logger.e('Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  /// Attempts to show the cached rewarded ad.
  ///
  /// [onRewardEarned] fires ONLY when the user actually watched the ad to the
  /// rewarded point — that's the only path callers should use to unlock a gated
  /// action. [onUnavailable] fires for every other outcome (no ad cached /
  /// offline / failed to show / closed early without earning), so the caller can
  /// surface an error and must NOT unlock. This closes the "go offline to skip
  /// the ad" bypass. Always preloads the next ad afterwards.
  ///
  /// Credits are **not** granted by the client. The ad carries this account's id as
  /// AdMob's server-side-verification user id, and Google calls the API directly once
  /// the ad genuinely completes; the API grants against that callback. [onRewardEarned]
  /// therefore means "the reward is on its way", not "the balance has changed".
  void show({
    required VoidCallback onRewardEarned,
    required VoidCallback onUnavailable,
  }) {
    final ad = _cachedAd;
    if (ad == null) {
      loadAd(); // try to have one ready next time
      onUnavailable();
      return;
    }
    _cachedAd = null;

    // Tells Google which account to credit when it calls our verification endpoint.
    // Without it the callback arrives with no user and nothing can be granted.
    final userId = AuthService().user?.id;
    if (userId != null && userId.isNotEmpty) {
      ad.setServerSideOptions(ServerSideVerificationOptions(userId: userId));
    }

    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadAd();
        if (earned) {
          onRewardEarned();
        } else {
          onUnavailable(); // closed before earning the reward
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadAd();
        LoggerSingleton().logger.e('Rewarded ad failed to show: $error');
        onUnavailable();
      },
    );
    ad.show(onUserEarnedReward: (ad, reward) => earned = true);
  }
}
