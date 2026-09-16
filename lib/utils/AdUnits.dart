import 'package:flutter/foundation.dart';

/// AdMob unit ids, keyed off the build mode.
///
/// Debug always uses Google's sample units. Release must use this account's own units: serving
/// Google's test ads to real users earns nothing and breaches the AdMob programme policy, which
/// risks the account rather than just the revenue.
class AdUnits {
  AdUnits._();

  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedInterstitial = 'ca-app-pub-3940256099942544/5354046379';

  static const _prodBanner = 'ca-app-pub-4715945578201106/3610792197';
  static const _prodInterstitial = 'ca-app-pub-4715945578201106/9362646476';
  static const _prodAppOpen = 'ca-app-pub-4715945578201106/5084422823';

  static const _prodRewarded = 'ca-app-pub-4715945578201106/5259576789';

  /// Rewarded interstitial: shown at a natural break when the user is out of credits.
  /// Unlike [rewarded], the user does not seek it out — which is exactly why Google
  /// requires an opt-out on the intro screen before it plays.
  static const _prodRewardedInterstitial = 'ca-app-pub-4715945578201106/3946495118';

  static String get banner => kDebugMode ? _testBanner : _prodBanner;

  static String get interstitial =>
      kDebugMode ? _testInterstitial : _prodInterstitial;

  static String get appOpen => kDebugMode ? _testAppOpen : _prodAppOpen;

  /// The rewarded unit, or null when no production unit has been configured.
  ///
  /// Callers must treat null as "rewarded ads are unavailable" and hide the feature, rather
  /// than falling back to the test unit.
  static String? get rewarded {
    if (kDebugMode) return _testRewarded;
    return _prodRewarded.isEmpty ? null : _prodRewarded;
  }

  /// The rewarded interstitial unit, or null when none is configured.
  static String? get rewardedInterstitial {
    if (kDebugMode) return _testRewardedInterstitial;
    return _prodRewardedInterstitial.isEmpty ? null : _prodRewardedInterstitial;
  }

  static bool get rewardedInterstitialAvailable => rewardedInterstitial != null;

  /// Whether the rewarded feature can be offered at all. Drives the UI so a user is never
  /// shown a way to earn credits that cannot work.
  static bool get rewardedAvailable => rewarded != null;
}
