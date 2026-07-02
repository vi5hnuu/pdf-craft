import 'package:flutter/material.dart';

/// Tool launcher hook.
///
/// Previously this **forced** heavy tools through a "watch an ad to continue"
/// dialog. That was high friction, so the app moved to a freemium model:
/// every tool now opens immediately. Monetization is handled elsewhere —
/// non-intrusive interstitials on completion for free users, an optional
/// "watch ad to support us" action, and a Pro upgrade that removes all ads
/// ([ProService]). This shim is kept so tool-launch call sites stay unchanged.
class RewardGate {
  RewardGate._();

  static Future<void> run(
    BuildContext context, {
    required bool isHeavy,
    required String toolName,
    required VoidCallback proceed,
  }) async {
    proceed();
  }
}
