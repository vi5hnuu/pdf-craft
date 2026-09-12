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

  static const _prodBanner = 'ca-app-pub-4715945578201106/3610792197';
  static const _prodInterstitial = 'ca-app-pub-4715945578201106/9362646476';
  static const _prodAppOpen = 'ca-app-pub-4715945578201106/5084422823';

  /// Not yet created in the AdMob console.
  ///
  /// This was set to the test unit, so release builds served Google's sample rewarded ad to
  /// real users — no revenue, and a policy breach that can cost the account. Left empty
  /// deliberately: an empty id disables rewarded ads rather than shipping test ones, and
  /// [rewarded] returning null is what the rest of the app keys off. Paste the real unit id
  /// here once it exists and the feature turns itself back on.
  static const _prodRewarded = '';

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

  /// Whether the rewarded feature can be offered at all. Drives the UI so a user is never
  /// shown a way to earn credits that cannot work.
  static bool get rewardedAvailable => rewarded != null;
}
