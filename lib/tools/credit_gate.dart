import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/credit_service.dart' as credits_service;
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/singletons/rewarded_interstitial_ad_manager.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/utils/upload_limits.dart';

/// Confirm-spend gate for paid tools.
///
/// Free tools (cost 0 / unpriced) run immediately. Paid tools first show a short
/// dialog with the price and the current balance; the tool proceeds only on confirm.
/// If the balance is too low, the dialog routes the user to the Credits screen instead.
/// (The server still enforces the real charge — this is a friendly heads-up, not the
/// security boundary.)
class CreditGate {
  CreditGate._();

  static Future<void> run(
    BuildContext context, {
    required String? creditToolId,
    required String toolName,
    required VoidCallback proceed,
    /// The files about to be processed, when they are already known. Supplying them lets
    /// the dialog quote the size surcharge the server will actually apply instead of the
    /// bare base price.
    List<File>? files,
  }) async {
    if (creditToolId == null) {
      proceed();
      return;
    }

    final int sizeBytes = UploadLimits.totalBytes(files);
    final cost = sizeBytes > 0
        ? CreditService().costForSize(creditToolId, sizeBytes)
        : CreditService().costFor(creditToolId);
    // When the files are not known yet (the picker has not run), the price can still grow
    // with size, so the dialog says "from N" rather than stating a figure it cannot promise.
    final approximate = sizeBytes == 0 && CreditService().hasSizeSurcharge(creditToolId);

    if (cost <= 0) {
      proceed();
      return;
    }

    final balance = CreditService().balance;
    final enough = balance >= cost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(toolName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.toll, size: 20),
                const SizedBox(width: 8),
                Text(
                    approximate
                        ? L10n.of(ctx).gateUsesFromCredits(cost)
                        : L10n.of(ctx).gateUsesCredits(cost),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (approximate) ...[
              const SizedBox(height: 4),
              Text(L10n.of(ctx).gateLargerFiles,
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(L10n.of(ctx).gateBalance(balance)),
            if (!enough) ...[
              const SizedBox(height: 8),
              Text(L10n.of(ctx).gateNotEnough,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L10n.of(ctx).cancel),
          ),
          // Out of credits: offer the ad alongside buying. This dialog doubles as the
          // introductory screen AdMob requires before a rewarded interstitial — it
          // states the reward and leaves Cancel plainly available, so the ad is never
          // forced on anyone. Shown only when an ad is actually cached, so the offer
          // is never a dead end.
          if (!enough && RewardedInterstitialAdManager().isReady)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
                RewardedInterstitialAdManager().show(
                  onRewardEarned: () {
                    // The credit itself is granted server-side from AdMob's
                    // verification callback, so refresh rather than adding locally.
                    credits_service.CreditService().refreshBalance();
                    NotificationService.showSnackbar(
                        text: L10n.current.gateAdReward, color: Colors.green);
                  },
                  onUnavailable: () => NotificationService.showSnackbar(
                      text: L10n.current.gateAdUnavailable, color: Colors.orange),
                );
              },
              child: Text(L10n.of(ctx).gateWatchAd),
            ),
          if (!enough)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
                GoRouter.of(context).pushNamed(AppRoutes.creditsRoute.name);
              },
              child: Text(L10n.of(ctx).gateGetCredits),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(L10n.of(ctx).gateUse(cost)),
            ),
        ],
      ),
    );

    if (confirmed == true) proceed();
  }
}
