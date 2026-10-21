import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/crash_reporter.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/singletons/full_screen_ad_policy.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/singletons/auth_service.dart';

/// What a redemption attempt amounted to, and therefore what happens to the purchase.
enum PurchaseOutcomeKind {
  /// The credits are on the caller's account.
  credited,

  /// This session is a guest, so the server will not credit it — but creating an account will,
  /// because conversion keeps the same account id and the purchase then matches.
  refusedNeedsAccount,

  /// The purchase is bound to a different account. Signing in to that one is the way to it.
  refusedOtherAccount,

  /// No answer yet: a grant in flight, an unreachable dependency, a dropped connection.
  deferred;

  /// Whether the purchase may be finalized and consumed.
  ///
  /// Only one kind says yes, and that is the point. Consuming is irreversible — Play never
  /// redelivers a consumed purchase — so **nothing but a confirmed credit may consume**. Every
  /// other kind leaves the purchase pending, which either lets a retry succeed or lets Play
  /// auto-refund it after three days. Breaking this rule is what destroyed purchases before: a
  /// 409 was read as "already credited", the purchase was consumed, and the credits were
  /// stranded on a session the device had lost.
  bool get mayConsume => this == credited;
}

/// Classifies a redemption attempt, with no I/O so the rules can be tested directly.
///
/// [statusCode] is null when the call succeeded; [callerIsGuest] only distinguishes which
/// refusal the user is told about, never whether the purchase is kept.
PurchaseOutcomeKind outcomeFor({
  required bool creditedToCaller,
  int? statusCode,
  required bool callerIsGuest,
}) {
  if (statusCode == null) {
    // The server credits the caller by construction, so a 200 that says otherwise should not
    // happen. If one ever does it is still not a credit, so it still must not be consumed.
    return creditedToCaller
        ? PurchaseOutcomeKind.credited
        : PurchaseOutcomeKind.refusedOtherAccount;
  }

  // 403 is the one refusal that will not resolve by retrying — but it does resolve if the user
  // converts or signs in, and failing that Play refunds it, so the purchase is still kept.
  if (statusCode == 403) {
    return callerIsGuest
        ? PurchaseOutcomeKind.refusedNeedsAccount
        : PurchaseOutcomeKind.refusedOtherAccount;
  }

  // 409 is a concurrent grant in flight, 503 the auth service being unreachable, 5xx/timeouts
  // everything else. All transient, all retried on the next delivery.
  return PurchaseOutcomeKind.deferred;
}

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

  /// The account the last restore ran for, so an identity change can be noticed.
  String? _restoredForUserId;

  bool get available => _available;
  bool get initialized => _initialized;
  bool get purchasePending => _purchasePending;
  ProductDetails? product(String id) => _products[id];

  /// Subscribe to the purchase stream, load products, and recover unfinished purchases.
  /// Safe to call once at startup (after auth is ready, since redeeming needs a token).
  Future<void> init() async {
    if (_sub != null) return; // already initialized
    // A session can end mid-use: a rejected refresh replaces the identity without the app
    // restarting. Any purchase bought by the old one is then owned by an account this device no
    // longer holds, and nothing would re-offer it until the next launch. Asking Play to redeliver
    // on an identity change is what lets it be recovered now rather than eventually.
    AuthService().addListener(_onIdentityMaybeChanged);
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
        _restoredForUserId = AuthService().user?.id;
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

  /// Starts buying a consumable credit pack.
  ///
  /// Returns false when the product is unavailable, or when the session is a guest.
  ///
  /// The guest check is here as well as in the UI because this is the one that cannot be
  /// bypassed. The server refuses to credit a guest, and Play would still take the money, so
  /// opening the purchase sheet for one sells something that cannot be delivered. The UI asks
  /// them to create an account instead; see CreditsScreen.
  Future<bool> buy(String productId) async {
    final details = _products[productId];
    if (details == null) return false;
    if (AuthService().isGuest) {
      LoggerSingleton().logger.w('Purchase refused: guests cannot be credited.');
      return false;
    }
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
      NotificationService.showSnackbar(text: L10n.current.purchaseCouldNotStart, kind: SnackKind.error);
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
              text: L10n.current.purchaseFailed, kind: SnackKind.error);
          await _finalizeIfPending(p); // clear the failed item from the queue
          break;

        case PurchaseStatus.canceled:
          _setPending(false);
          await _finalizeIfPending(p);
          break;
      }
    }
  }

  /// Verifies the purchase server-side and consumes it only once the credits are confirmed.
  Future<void> _deliverAndFinalize(PurchaseDetails p) async {
    // Breadcrumbs only — product id and status, never the purchase token.
    CrashReporter().log('purchase deliver ${p.productID} ${p.status.name}');
    final token = p.verificationData.serverVerificationData;

    PurchaseOutcomeKind outcome;
    try {
      final result = await CreditService().redeemPurchase(token, p.productID);
      outcome = outcomeFor(
          creditedToCaller: result.creditedToCaller,
          callerIsGuest: AuthService().isGuest);
    } on DioException catch (e) {
      // A transport failure has no status; it is deferred either way, which is what
      // outcomeFor returns for an unrecognised code.
      outcome = outcomeFor(
          creditedToCaller: false,
          statusCode: e.response?.statusCode ?? 0,
          callerIsGuest: AuthService().isGuest);
      LoggerSingleton().logger.w('Purchase redemption failed (${e.response?.statusCode}): $e');
    } catch (e) {
      outcome = outcomeFor(
          creditedToCaller: false, statusCode: 0, callerIsGuest: AuthService().isGuest);
      LoggerSingleton().logger.w('Purchase redemption failed: $e');
    }

    // The single gate. Everything above decides what happened; only this consumes.
    if (outcome.mayConsume) {
      await _consumeCredited(p);
      NotificationService.showSnackbar(
          text: L10n.current.creditsAdded, kind: SnackKind.success);
      return;
    }

    if (outcome != PurchaseOutcomeKind.deferred) {
      CrashReporter().log('purchase refused ${p.productID} ${outcome.name}');
    }
    NotificationService.showSnackbar(
      text: switch (outcome) {
        PurchaseOutcomeKind.refusedNeedsAccount => L10n.current.purchaseNeedsAccount,
        PurchaseOutcomeKind.refusedOtherAccount => L10n.current.purchaseOtherAccount,
        // Says "verifying" because that is the truth: the purchase is held, not lost, and the
        // next launch tries again.
        _ => L10n.current.purchaseVerifying,
      },
      kind: SnackKind.warning,
    );
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

  /// Re-offers past purchases when the signed-in account changes.
  ///
  /// Only on a real change, and only once per identity: AuthService notifies for plenty of
  /// things that are not one, and restoring in a loop would re-run delivery for every purchase
  /// each time.
  void _onIdentityMaybeChanged() {
    if (!_available) return;
    final current = AuthService().user?.id;
    if (current == null || current == _restoredForUserId) return;
    _restoredForUserId = current;
    _iap.restorePurchases().catchError(
        (e) => LoggerSingleton().logger.w('Restore after identity change failed: $e'));
  }

  @override
  void dispose() {
    AuthService().removeListener(_onIdentityMaybeChanged);
    _sub?.cancel();
    super.dispose();
  }
}
