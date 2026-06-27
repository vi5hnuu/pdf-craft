import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';

/// Manages a single cached Rewarded ad, shown (opt-in) before "heavy" /
/// server-side operations so those expensive tools can stay free.
///
/// Mirrors [AppOpenAdManager]: load/cache, show, then preload the next.
class RewardedAdManager {
  // Google's public TEST rewarded ad unit. Replace with the real AdMob rewarded
  // unit id before release.
  static const String _adUnitId = 'ca-app-pub-3940256099942544/5224354917';

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
    _isLoading = true;
    RewardedAd.load(
      adUnitId: _adUnitId,
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

  /// Shows the cached ad if available and reports completion via [onComplete]
  /// (true when the reward was earned). If no ad is ready it completes
  /// immediately with `false` and preloads one — callers should treat that as
  /// "proceed anyway" so users are never blocked by ad availability. Always
  /// preloads the next ad afterwards.
  void show({required void Function(bool earnedReward) onComplete}) {
    final ad = _cachedAd;
    if (ad == null) {
      loadAd();
      onComplete(false);
      return;
    }
    _cachedAd = null;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadAd();
        onComplete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadAd();
        LoggerSingleton().logger.e('Rewarded ad failed to show: $error');
        onComplete(false);
      },
    );
    ad.show(onUserEarnedReward: (ad, reward) => earned = true);
  }
}
