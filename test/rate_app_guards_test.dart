import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/singletons/rate_app_service.dart';

/// The decision of *when* to ask is the whole feature, so it is pinned here without a device, a
/// store or a real clock. Thresholds come from AppConfigService, which with no server answer
/// reports its unrestricted defaults: 3 successes, 3 days, 60 days between asks.
void main() {
  final service = RateAppService();
  final now = DateTime(2026, 10, 18, 12);
  final longAgo = now.subtract(const Duration(days: 30));

  bool ask({int successes = 5, DateTime? firstSuccess, int? lastAskMs}) => service.shouldAsk(
        successes: successes,
        firstSuccess: firstSuccess ?? longAgo,
        lastAskMs: lastAskMs,
        now: now,
      );

  test('asks once every guard is satisfied', () {
    expect(ask(), isTrue);
  });

  test('refuses before enough successful runs', () {
    expect(ask(successes: 2), isFalse);
    expect(ask(successes: 3), isTrue, reason: 'the threshold itself should qualify');
  });

  test('refuses until the app has been used for long enough', () {
    // Someone three minutes into their first session has no opinion worth asking for.
    expect(ask(firstSuccess: now.subtract(const Duration(hours: 2))), isFalse);
  });

  test('refuses inside the cool-off since the last ask', () {
    final yesterday = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    expect(ask(lastAskMs: yesterday), isFalse);

    final lastYear = now.subtract(const Duration(days: 400)).millisecondsSinceEpoch;
    expect(ask(lastAskMs: lastYear), isTrue);
  });

  test('refuses for the rest of the session once anything has failed', () {
    // Asking for a rating right after something of theirs broke is how an app earns one star.
    service.noteError();
    expect(ask(), isFalse);
    expect(ask(successes: 500, lastAskMs: null), isFalse,
        reason: 'no amount of later success should rescue a session that already failed');
  });
}
