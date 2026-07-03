import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

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
      return await _iap.buyConsumable(
          purchaseParam: PurchaseParam(productDetails: details));
    } catch (e) {
      LoggerSingleton().logger.w('buyConsumable failed: $e');
      NotificationService.showSnackbar(text: 'Could not start purchase.', color: Colors.red);
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
              text: 'Purchase failed. You have not been charged.', color: Colors.red);
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
        await _finalizeIfPending(p);
        NotificationService.showSnackbar(text: 'Credits added!', color: Colors.green);
      }
    } catch (e) {
      // Transient/verification failure — DO NOT finalize. Play will redeliver it and we
      // retry on the next update/launch, so the user isn't charged without credits.
      LoggerSingleton().logger.w('Purchase verification deferred (will retry): $e');
      NotificationService.showSnackbar(
          text: 'Verifying your purchase… credits will appear shortly.', color: Colors.orange);
    }
  }

  Future<void> _finalizeIfPending(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }

  void _setPending(bool value) {
    if (_purchasePending != value) {
      _purchasePending = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
