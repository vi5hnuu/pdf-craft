import 'package:flutter/foundation.dart';
import 'package:pdf_craft/singletons/ProService.dart';

/// Decides whether a full-screen ad (interstitial or app-open) may be shown **right now**.
///
/// Single responsibility: policy only. [AdsSingleton] and [AppOpenAdManager] still load and
/// show ads; they ask this class first. Keeping the rules in one place means every one of the
/// ~30 "show interstitial" call sites follows the same limits without being edited.
///
/// The rules exist because the app used to:
///  - show an interstitial after **every** successful tool run, including runs the user had just
///    paid credits for, and
///  - show an app-open ad whenever the app returned from *any* system UI (notification shade,
///    permission dialog, Google account picker, document scanner, share sheet), even for Pro users.
class FullScreenAdPolicy {
  static final FullScreenAdPolicy _instance =
      FullScreenAdPolicy._(DateTime.now, () => ProService().isPro);

  factory FullScreenAdPolicy() => _instance;

  FullScreenAdPolicy._(this._now, this._isPro);

  /// Test constructor with an injectable clock and entitlement.
  @visibleForTesting
  FullScreenAdPolicy.forTest({
    required DateTime Function() clock,
    required bool Function() isPro,
  })  : _now = clock,
        _isPro = isPro;

  /// Minimum gap between any two full-screen ads.
  static const Duration cooldown = Duration(minutes: 3);

  /// A credit charge this recent means the run that just finished was paid for.
  static const Duration paidRunWindow = Duration(minutes: 2);

  /// The app must have been genuinely in the background at least this long before an app-open
  /// ad is allowed — quick trips to system UI never qualify.
  static const Duration minBackground = Duration(seconds: 30);

  final DateTime Function() _now;
  final bool Function() _isPro;

  DateTime? _lastShownAt;
  DateTime? _lastChargeAt;
  DateTime? _pausedAt;

  /// Number of in-app flows currently running in another activity (scanner, purchase, Google
  /// sign-in, share sheet…). While > 0, returning to the app is not a "resume" worth an ad.
  int _externalFlows = 0;

  /// Call whenever a full-screen ad is actually shown.
  void recordShown() => _lastShownAt = _now();

  /// Call when the server reports a credit charge (X-Credits-Remaining on a response).
  void recordCharge() => _lastChargeAt = _now();

  /// Call on [AppLifecycleState.paused] only — `inactive`/`hidden` fire for the notification
  /// shade and system dialogs and must not count as leaving the app. Keeps the earliest pause.
  void onPaused() => _pausedAt ??= _now();

  bool _inCooldown(DateTime now) =>
      _lastShownAt != null && now.difference(_lastShownAt!) < cooldown;

  /// Whether an interstitial may be shown after a tool run.
  bool canShowInterstitial() {
    if (_isPro()) return false;
    final now = _now();
    if (_inCooldown(now)) return false;
    // Never follow a run the user paid credits for with an ad.
    if (_lastChargeAt != null && now.difference(_lastChargeAt!) < paidRunWindow) return false;
    return true;
  }

  /// Call on [AppLifecycleState.resumed]. Consumes the recorded pause and reports whether an
  /// app-open ad may be shown for this return.
  bool consumeResumeForAppOpen() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null || _isPro() || _externalFlows > 0) return false;
    final now = _now();
    if (now.difference(pausedAt) < minBackground) return false;
    return !_inCooldown(now);
  }

  /// Runs [flow] — which leaves the app's activity (scanner, purchase, sign-in, share…) — while
  /// suppressing the app-open ad that the return trip would otherwise trigger.
  Future<T> runExternal<T>(Future<T> Function() flow) async {
    _externalFlows++;
    try {
      return await flow();
    } finally {
      _externalFlows--;
    }
  }
}
