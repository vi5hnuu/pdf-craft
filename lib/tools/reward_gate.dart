import 'package:flutter/material.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/singletons/RewardedAdManager.dart';
import 'package:pdf_craft/widgets/ConfirmDialog.dart';

/// Opt-in rewarded-ad gate for "heavy" (server-side / expensive) tools.
///
/// Per AdMob policy rewarded ads must be user-initiated, so for heavy tools we
/// ask first. The gated action unlocks ONLY if the user actually earns the
/// reward (watches the ad). If no ad is available (e.g. offline) or the ad is
/// closed early, the action does NOT proceed — otherwise users could bypass the
/// gate simply by going offline. Light tools run immediately.
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
      // Only unlock when the reward is genuinely earned.
      onRewardEarned: () {
        if (context.mounted) proceed();
      },
      // No ad / offline / closed early — do not unlock; tell the user why.
      onUnavailable: () {
        NotificationService.showSnackbar(
          text: 'No ad available right now. Check your internet and try again.',
          color: Colors.orange,
        );
      },
    );
  }
}
