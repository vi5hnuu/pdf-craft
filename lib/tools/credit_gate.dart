import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/routes/app_router.dart';
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

  /// Returns true when [proceed] ran, so the caller can tell "the user went ahead" from
  /// "the user backed out" — previously indistinguishable, which is why callers dropped the
  /// user's selection before finding out.
  ///
  /// [proceed] receives a context that is guaranteed to still be mounted. The caller's own
  /// context frequently is not: the selection bar's sheet pops before this dialog opens, taking
  /// the element the caller handed in with it, and routing from a defunct element silently did
  /// nothing — which is what broke every priced tool launched from a file selection.
  static Future<bool> run(
    BuildContext context, {
    required String? creditToolId,
    required String toolName,
    required void Function(BuildContext routeContext) proceed,
    /// The files about to be processed, when they are already known. Supplying them lets
    /// the dialog quote the size surcharge the server will actually apply instead of the
    /// bare base price.
    List<File>? files,
  }) async {
    if (creditToolId == null) {
      proceed(context);
      return true;
    }

    final int sizeBytes = UploadLimits.totalBytes(files);
    final cost = sizeBytes > 0
        ? CreditService().costForSize(creditToolId, sizeBytes)
        : CreditService().costFor(creditToolId);
    // When the files are not known yet (the picker has not run), the price can still grow
    // with size, so the dialog says "from N" rather than stating a figure it cannot promise.
    final approximate = sizeBytes == 0 && CreditService().hasSizeSurcharge(creditToolId);

    if (cost <= 0) {
      proceed(context);
      return true;
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

    if (confirmed != true) return false;
    // Deliberately NOT the caller's context. The dialog was open for an unbounded time and the
    // thing that opened it is frequently gone — the selection bar's sheet pops before this
    // dialog even appears, so routing from the caller's element silently did nothing. Resolving
    // the root navigator here, after the await, means there is no stale context to reason about.
    final host = rootNavigatorKey.currentContext;
    if (host == null) return false;
    // The lint cannot see that `host` was resolved *after* the await rather than captured
    // before it; a GlobalKey's currentContext is null when unmounted, and that is checked above.
    // ignore: use_build_context_synchronously
    proceed(host);
    return true;
  }
}
