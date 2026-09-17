import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/singletons/full_screen_ad_policy.dart';

/// Full-screen ads interrupt the user, so the rules deciding when they may appear must hold:
/// a cooldown between ads, never right after a paid run, never for Pro, and app-open ads only
/// after a genuine trip to the background.
void main() {
  late DateTime now;
  late bool pro;
  late FullScreenAdPolicy policy;

  setUp(() {
    now = DateTime(2026, 9, 15, 12);
    pro = false;
    policy = FullScreenAdPolicy.forTest(clock: () => now, isPro: () => pro);
  });

  group('interstitial', () {
    test('allowed by default, then blocked during the cooldown', () {
      expect(policy.canShowInterstitial(), isTrue);
      policy.recordShown();
      now = now.add(const Duration(minutes: 2));
      expect(policy.canShowInterstitial(), isFalse);
      now = now.add(const Duration(minutes: 2));
      expect(policy.canShowInterstitial(), isTrue);
    });

    test('skipped right after a paid run', () {
      policy.recordCharge();
      now = now.add(const Duration(seconds: 5));
      expect(policy.canShowInterstitial(), isFalse);
      now = now.add(const Duration(minutes: 3));
      expect(policy.canShowInterstitial(), isTrue);
    });

    test('never for Pro users', () {
      pro = true;
      expect(policy.canShowInterstitial(), isFalse);
    });
  });

  group('app-open', () {
    test('needs a pause first', () {
      expect(policy.consumeResumeForAppOpen(), isFalse);
    });

    test('a short trip away does not qualify', () {
      policy.onPaused();
      now = now.add(const Duration(seconds: 10));
      expect(policy.consumeResumeForAppOpen(), isFalse);
    });

    test('a long background qualifies once, and the pause is consumed', () {
      policy.onPaused();
      now = now.add(const Duration(minutes: 1));
      expect(policy.consumeResumeForAppOpen(), isTrue);
      expect(policy.consumeResumeForAppOpen(), isFalse);
    });

    test('respects the shared cooldown with interstitials', () {
      policy.recordShown();
      policy.onPaused();
      now = now.add(const Duration(minutes: 1));
      expect(policy.consumeResumeForAppOpen(), isFalse);
    });

    test('suppressed while an external flow is running', () async {
      await policy.runExternal(() async {
        policy.onPaused();
        now = now.add(const Duration(minutes: 5));
        expect(policy.consumeResumeForAppOpen(), isFalse);
      });
    });

    test('never for Pro users', () {
      pro = true;
      policy.onPaused();
      now = now.add(const Duration(minutes: 5));
      expect(policy.consumeResumeForAppOpen(), isFalse);
    });
  });
}
