import 'package:flutter/material.dart';
import 'package:pdf_craft/singletons/RewardedAdManager.dart';
import 'package:pdf_craft/widgets/ConfirmDialog.dart';

/// Opt-in rewarded-ad gate for "heavy" (server-side / expensive) tools.
///
/// Per AdMob policy rewarded ads must be user-initiated, so for heavy tools we
/// ask first. If the user agrees we show the ad and then proceed; if no ad is
/// available we proceed anyway (the gate monetizes but never hard-blocks). Light
/// tools run immediately.
class RewardGate {
  RewardGate._();

  static Future<void> run(
    BuildContext context, {
    required bool isHeavy,
    required String toolName,
    required VoidCallback proceed,
  }) async {
    if (!isHeavy) {
      proceed();
      return;
    }

    final result = await ConfirmDialog.show(
      context,
      title: toolName,
      message:
          'This is an advanced operation. Watch a short ad to continue — it helps keep these tools free.',
      confirmLabel: 'Watch ad',
      cancelLabel: 'Not now',
      icon: Icons.play_circle_outline,
    );
    if (!result.confirmed) return;

    RewardedAdManager().show(
      onComplete: (_) {
        // Proceed whether or not a reward was earned / an ad was available.
        if (context.mounted) proceed();
      },
    );
  }
}
