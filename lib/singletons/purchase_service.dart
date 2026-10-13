import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/singletons/full_screen_ad_policy.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/singletons/auth_service.dart';

/// Owns the Google Play In-App Purchase lifecycle **app-wide** (not per-screen), so a
/// purchase that completes after the user navigates away — or that Play redelivers on a
/// later launch — is still processed.
///
/// Correctness rules enforced here:
///  - A purchase is **only finalized (consumed) after the server has credited it** (or
///    confirmed it was already credited). If the server can't verify it right now, the
///    purchase is left pending so Play redelivers it and we retry — the user is never
///    charged without receiving credits.
///  - [init] calls `restorePurchases()` to recover any purchase left unfinished by a
///    previous session (e.g. the app was killed mid-flow).
class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._();
  PurchaseService._();
  factory PurchaseService() => _instance;

  /// Must match the Play Console INAPP product ids and the server's PRODUCT_CREDITS map.
  static const Set<String> productIds = {
    'pdfcraft_credits_10',
    'pdfcraft_credits_30',
    'pdfcraft_credits_60',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, ProductDetails> _products = {};
  bool _available = false;
  bool _initialized = false;
  bool _purchasePending = false;

  bool get available => _available;
  bool get initialized => _initialized;
  bool get purchasePending => _purchasePending;
  ProductDetails? product(String id) => _products[id];

  /// Subscribe to the purchase stream, load products, and recover unfinished purchases.
  /// Safe to call once at startup (after auth is ready, since redeeming needs a token).
  Future<void> init() async {
    if (_sub != null) return; // already initialized
    // Subscribe FIRST so we don't miss restored/redelivered purchases.
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) => LoggerSingleton().logger.w('Purchase stream error: $e'),
    );
    try {
      _available = await _iap.isAvailable();
      if (_available) {
        final resp = await _iap.queryProductDetails(productIds);
        for (final d in resp.productDetails) {
          _products[d.id] = d;
        }
        // Recover any purchase left unfinished by a previous session.
        await _iap.restorePurchases();
      }
    } catch (e) {
      LoggerSingleton().logger.w('IAP init failed: $e');
      _available = false;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Starts buying a consumable credit pack. Returns false if the product isn't available.
  Future<bool> buy(String productId) async {
    final details = _products[productId];
    if (details == null) return false;
    try {
      // Attach the userId as Play's obfuscated account id. It is the only way the server
      // can tell whose account to credit when it reconciles a purchase from an RTDN — the
      // notification carries the token but no identity, so a purchase completed while the
      // app was killed would otherwise be unrecoverable.
      // The Play purchase sheet leaves the activity; don't greet the buyer with an app-open ad.
      return await FullScreenAdPolicy().runExternal(() => _iap.buyConsumable(
            purchaseParam: PurchaseParam(
              productDetails: details,
              applicationUserName: AuthService().user?.id,
            ),
            // The plugin's default is autoConsume: true, which consumes the purchase and
            // *awaits* that before the result ever reaches _onPurchaseUpdates. The token was
            // therefore already gone by the time the server was asked to credit it, so the
            // retry this class promises could never happen: a consumed one-time purchase is
            // not returned by queryPurchases, so restorePurchases() could not see it again and
            // any single failure lost the credits for good. Consuming is done in
            // _deliverAndFinalize instead, once the server has credited.
            autoConsume: false,
          ));
    } catch (e) {
      LoggerSingleton().logger.w('buyConsumable failed: $e');
      NotificationService.showSnackbar(text: L10n.current.purchaseCouldNotStart, color: Colors.red);
      return false;
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _setPending(true);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _setPending(false);
          await _deliverAndFinalize(p);
          break;

        case PurchaseStatus.error:
          _setPending(false);
          LoggerSingleton().logger.w('Purchase error: ${p.error}');
          NotificationService.showSnackbar(
              text: L10n.current.purchaseFailed, color: Colors.red);
          await _finalizeIfPending(p); // clear the failed item from the queue
          break;

        case PurchaseStatus.canceled:
          _setPending(false);
          await _finalizeIfPending(p);
          break;
      }
    }
  }

  /// Verifies the purchase server-side and, only on success, finalizes (consumes) it.
  Future<void> _deliverAndFinalize(PurchaseDetails p) async {
    try {
      final credited = await CreditService()
          .redeemPurchase(p.verificationData.serverVerificationData, p.productID);
      if (credited) {
        await _consumeCredited(p);
        NotificationService.showSnackbar(text: L10n.current.creditsAdded, color: Colors.green);
      }
    } catch (e) {
      // Transient/verification failure — DO NOT finalize. Play will redeliver it and we
      // retry on the next update/launch, so the user isn't charged without credits.
      LoggerSingleton().logger.w('Purchase verification deferred (will retry): $e');
      NotificationService.showSnackbar(
          text: L10n.current.purchaseVerifying, color: Colors.orange);
    }
  }

  Future<void> _finalizeIfPending(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }

  /// Finalizes a credited purchase: acknowledge it, then **consume** it.
  ///
  /// Both steps are needed. On Android `completePurchase` only acknowledges, and Play will not
  /// sell a consumable again until it is consumed — so acknowledging alone would credit the user
  /// once and then refuse every later purchase of the same product. Consuming is Android-only,
  /// hence the platform guard; acknowledging is what finalizes it everywhere else.
  ///
  /// Nothing here runs until the server has credited the purchase, which is what keeps the
  /// promise at the top of this class: until it does, the purchase stays unconsumed and
  /// unacknowledged, so Play keeps returning it to [restore] and we retry. Play auto-refunds a
  /// purchase left unacknowledged for three days, so a purchase we can never credit ends with the
  /// user's money back rather than with credits they paid for and never got.
  Future<void> _consumeCredited(PurchaseDetails p) async {
    await _finalizeIfPending(p);
    if (!Platform.isAndroid) return;
    try {
      await _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(p);
    } catch (e) {
      // The credits are already granted and the purchase acknowledged, so this is not a
      // failure the user should see — but it does mean they cannot re-buy this product until
      // Play expires the entitlement, so it must be visible to us.
      LoggerSingleton().logger.w('Consume failed after crediting: $e');
    }
  }

  void _setPending(bool value) {
    if (_purchasePending != value) {
      _purchasePending = value;
      notifyListeners();
    }
  }

  /// Re-checks Google Play for purchases this device has made.
  ///
  /// [init] already does this at launch, but a user who reinstalls, changes device or simply
  /// does not see credits arrive had no way to ask for it. The purchase stream handles whatever
  /// comes back, so this only has to trigger the query.
  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      LoggerSingleton().logger.w('Restore purchases failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
