import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/utils/AdUnits.dart';

/// Manages a single cached Rewarded Interstitial ad, offered when a user runs out
/// of credits.
///
/// The difference from [RewardedAdManager] is who starts it: a rewarded ad is
/// something the user goes looking for, while this one is offered at a natural
/// break. Google's policy for that is explicit — the app must show an
/// introductory screen announcing the reward with a clear, working opt-out and
/// enough time to take it. Apps that skip it get their ads restricted, so
/// [show] is deliberately not callable without having offered that choice
/// first: see `RewardedIntroDialog`, which is the only intended caller.
class RewardedInterstitialAdManager {
  static String? get _adUnitId => AdUnits.rewardedInterstitial;

  RewardedInterstitialAd? _cachedAd;
  bool _isLoading = false;

  static final RewardedInterstitialAdManager _instance = RewardedInterstitialAdManager._();
  RewardedInterstitialAdManager._();
  factory RewardedInterstitialAdManager() => _instance;

  bool get isReady => _cachedAd != null;

  /// Loads and caches one ad. No-ops while loading or already cached.
  void loadAd() {
    if (_isLoading || _cachedAd != null) return;
    final adUnitId = _adUnitId;
    if (adUnitId == null) {
      LoggerSingleton().logger.w(
          'Rewarded interstitial disabled: no production ad unit configured.');
      return;
    }
    _isLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(keywords: [
        'pdf', 'document', 'compress', 'convert', 'merge', 'scanner'
      ]),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _cachedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          LoggerSingleton().logger.e('Rewarded interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Shows the cached ad. Call only after the user has accepted on the intro
  /// screen.
  ///
  /// [onRewardEarned] fires only when the ad was genuinely watched to the
  /// rewarded point; every other outcome goes to [onUnavailable] so the caller
  /// never unlocks anything for a dismissed ad. As with rewarded ads the credit
  /// itself is granted server-side from AdMob's verification callback, keyed by
  /// the account id attached below — the client only learns that a reward is on
  /// its way.
  void show({
    required VoidCallback onRewardEarned,
    required VoidCallback onUnavailable,
  }) {
    final ad = _cachedAd;
    if (ad == null) {
      loadAd();
      onUnavailable();
      return;
    }
    _cachedAd = null;

    final userId = AuthService().user?.id;
    if (userId != null && userId.isNotEmpty) {
      ad.setServerSideOptions(ServerSideVerificationOptions(userId: userId));
    }

    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadAd();
        earned ? onRewardEarned() : onUnavailable();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadAd();
        LoggerSingleton().logger.e('Rewarded interstitial failed to show: $error');
        onUnavailable();
      },
    );
    ad.show(onUserEarnedReward: (ad, reward) => earned = true);
  }
}
