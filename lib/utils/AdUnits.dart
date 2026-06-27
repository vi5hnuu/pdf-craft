import 'package:flutter/foundation.dart';

/// Central source of AdMob ad unit IDs.
///
/// In debug builds we always serve Google's public **test** ad units — showing
/// real ads during development risks invalid-traffic strikes on the AdMob
/// account. Release builds use the real production units.
class AdUnits {
  AdUnits._();

  // Google's official test ad units (safe to click during development).
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // Real production units.
  static const _prodBanner = 'ca-app-pub-4715945578201106/3610792197';
  static const _prodInterstitial = 'ca-app-pub-4715945578201106/9362646476';
  static const _prodAppOpen = 'ca-app-pub-4715945578201106/5084422823';
  // TODO: replace with the real Rewarded unit id once created in AdMob.
  static const _prodRewarded = _testRewarded;

  static String get banner => kDebugMode ? _testBanner : _prodBanner;
  static String get interstitial =>
      kDebugMode ? _testInterstitial : _prodInterstitial;
  static String get appOpen => kDebugMode ? _testAppOpen : _prodAppOpen;
  static String get rewarded => kDebugMode ? _testRewarded : _prodRewarded;
}
