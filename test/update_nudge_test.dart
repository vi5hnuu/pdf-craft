import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/widgets/update_nudge.dart';

/// The nudge's cool-off, which is the whole of its politeness.
///
/// A nudge that returns on every launch trains people to dismiss it without reading, which costs
/// the hard update gate its credibility too — so these pin that it stays quiet, and that a
/// genuinely new release is still allowed to speak up.
void main() {
  final now = DateTime(2026, 10, 19, 12);

  test('asks when it has never asked before', () {
    expect(
      UpdateNudge.shouldShow(recommendedBuild: 25, lastShownMs: null, now: now),
      isTrue,
    );
  });

  test('stays quiet about the same build inside the cool-off', () {
    expect(
      UpdateNudge.shouldShow(
        recommendedBuild: 25,
        lastShownBuild: 25,
        lastShownMs: now.subtract(const Duration(days: 6)).millisecondsSinceEpoch,
        now: now,
      ),
      isFalse,
    );
  });

  test('asks again about the same build once the cool-off has passed', () {
    expect(
      UpdateNudge.shouldShow(
        recommendedBuild: 25,
        lastShownBuild: 25,
        lastShownMs: now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
        now: now,
      ),
      isTrue,
    );
  });

  test('asks straight away about a newer build', () {
    // A release the user has not been told about is not the one they dismissed.
    expect(
      UpdateNudge.shouldShow(
        recommendedBuild: 26,
        lastShownBuild: 25,
        lastShownMs: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        now: now,
      ),
      isTrue,
    );
  });
}
