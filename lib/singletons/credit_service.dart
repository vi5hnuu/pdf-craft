import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:pdf_craft/singletons/auth_service.dart';
import 'package:pdf_craft/singletons/dio_singleton.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/singletons/pro_service.dart';
import 'package:pdf_craft/utils/constants.dart';

/// Client-side view of the user's credit balance and the per-tool price list.
///
/// Talks to pdf-studio's `/credits/*` endpoints (authenticated via the shared Dio
/// interceptor). Exposes the balance for the app bar and the cost lookup used to show
/// price badges and confirm-spend dialogs. A [ChangeNotifier] so UI updates on change.
class CreditService extends ChangeNotifier with WidgetsBindingObserver {
  static final CreditService _instance = CreditService._();
  CreditService._() {
    // Keep the balance in sync with the signed-in user: whenever the account changes
    // (login, logout, guest fallback, session expiry) reload it for the new user.
    AuthService().addListener(_onAuthChanged);
    _lastUserId = AuthService().user?.id;
    // Refresh when the app returns to the foreground (e.g. after the backend comes up).
    WidgetsBinding.instance.addObserver(this);
  }
  factory CreditService() => _instance;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_loaded) {
        load();
        return;
      }
      refreshBalance();
      // Repair a cost table that an earlier attempt failed to fetch, so a single
      // start-up blip does not leave every tool looking free until the app restarts.
      if (!_costsLoaded) _reloadCosts();
    }
  }

  final _dio = DioSingleton().dio;

  int _balance = 0;
  Map<String, ToolCost> _costs = {}; // toolId -> full pricing row
  bool _loaded = false;

  /// Whether the cost table was actually fetched.
  ///
  /// Separate from [_loaded]: start-up races the guest token, so /credits/costs often
  /// answers 401 on a cold start. That left the table empty while [_loaded] still said
  /// "done", so every tool priced itself at 0, [CreditGate] saw a free tool and skipped
  /// the confirm-spend dialog — the user was never told a tool costs credits, for the
  /// whole session, while the server charged anyway.
  bool _costsLoaded = false;
  String? _lastUserId;

  void _onAuthChanged() {
    final id = AuthService().user?.id;
    if (id != _lastUserId) {
      _lastUserId = id;
      refreshBalance(); // different account → its own balance
      // Now that a token exists, retry the pricing that a cold start could not fetch.
      // Also re-read it on a genuine account switch, since pricing can differ per account.
      _reloadCosts();
    }
  }

  int get balance => _balance;
  bool get loaded => _loaded;

  /// Headline (base) credit cost of a tool, 0 = free.
  int costFor(String toolId) => _costs[toolId]?.baseCredits ?? 0;

  bool isPaid(String toolId) => costFor(toolId) > 0;

  /// Cost for an actual input size, including the server's per-block surcharge.
  ///
  /// The server charges base + (bytes / unitSize) * creditsPerUnit. Quoting only the base
  /// meant a dialog could say "uses 2 credits" and then 6 were taken for a 20 MB compress;
  /// the full pricing row is already returned by /credits/costs, it was simply discarded.
  int costForSize(String toolId, int sizeBytes) =>
      _costs[toolId]?.costFor(sizeBytes) ?? 0;

  /// True when a tool's price grows with input size, so the UI can say "from N".
  bool hasSizeSurcharge(String toolId) => _costs[toolId]?.hasSizeComponent ?? false;

  /// Loads balance + cost table. Safe to call at startup; failures are non-fatal.
  Future<void> load() async {
    await Future.wait([refreshBalance(), _loadCosts()]);
    _loaded = true;
    notifyListeners();
  }

  /// Records a balance the server has just reported.
  ///
  /// Used by the Dio interceptor, which sees `X-Credits-Remaining` on every charged
  /// response — cheaper and more timely than each screen re-fetching after its own run.
  void setBalance(int credits) {
    if (credits == _balance) return;
    _balance = credits;
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    try {
      final res = await _dio.get('${Constants.baseUrl}/credits/balance');
      final data = res.data['data'] as Map;
      _balance = (data['credits'] as num).toInt();
      // The ad-free entitlement rides along on this call, so the client never has to rely on
      // its own cached copy while it is online.
      final adFree = data['ad_free'];
      if (adFree is bool) unawaited(ProService().applyFromServer(adFree: adFree));
      notifyListeners();
    } catch (e) {
      LoggerSingleton().logger.w('Balance fetch failed: $e');
    }
  }

  Future<void> _loadCosts() async {
    try {
      final res = await _dio.get('${Constants.baseUrl}/credits/costs');
      final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
      _costs = {
        for (final row in list) row['toolId'] as String: ToolCost.fromJson(row)
      };
      _costsLoaded = true;
    } catch (e) {
      LoggerSingleton().logger.w('Costs fetch failed: $e');
    }
  }

  /// Re-fetches the cost table and tells listeners, so any screen already showing a
  /// price picks the real one up.
  Future<void> _reloadCosts() async {
    await _loadCosts();
    if (_costsLoaded) notifyListeners();
  }

  /// Whether the pricing table is known. Callers that must not imply "free" when the
  /// price is merely unknown can check this.
  bool get costsLoaded => _costsLoaded;

  /// Fetches the pricing table if it is not already known, and reports whether it now is.
  ///
  /// For callers that are about to make a decision that depends on the price — [CreditGate]
  /// above all. A cold start races the guest token, so the start-up fetch often 401s; without
  /// this, the first tool the user opens is priced from an empty table and looks free.
  Future<bool> ensureCostsLoaded() async {
    if (_costsLoaded) return true;
    // Single-flighted and time-boxed. This sits in front of the confirm dialog on every priced
    // tool, so without the first a burst of taps starts a fetch each, and without the second an
    // offline tap left the screen doing nothing visible for the full connect timeout.
    final inFlight = _inFlightCosts ??= _reloadCosts().whenComplete(() => _inFlightCosts = null);
    try {
      await inFlight.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      // The fetch carries on in the background; this caller just stops waiting on it.
    }
    return _costsLoaded;
  }

  Future<void>? _inFlightCosts;

  /// Claims the daily free allowance. Returns the granted amount (throws on 409 if already claimed).
  Future<int> claimDaily() async {
    final res = await _dio.post('${Constants.baseUrl}/credits/daily');
    _balance = (res.data['data']['credits'] as num).toInt();
    notifyListeners();
    return (res.data['data']['granted'] as num).toInt();
  }

  /// Waits for the credits an ad earned to land, and reports how many arrived.
  ///
  /// The client no longer grants these. AdMob calls the API's verification endpoint once
  /// the ad genuinely completes, so the credit appears a moment later and out of band —
  /// asking the server to grant would have meant trusting the client, which is exactly
  /// what a modified build would abuse. This polls briefly for the balance to move.
  ///
  /// Returns the number of credits gained, or 0 if the callback has not arrived in time
  /// (it may still land; the balance refreshes on the next read either way).
  Future<int> awaitRewardedCredits({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final before = _balance;
    final deadline = DateTime.now().add(timeout);

    // Google's callback is usually near-instant, so start tight and back off rather than
    // hammering the API for the whole window.
    var wait = const Duration(milliseconds: 700);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(wait);
      await refreshBalance();
      if (_balance > before) return _balance - before;
      wait *= 2;
      if (wait > const Duration(seconds: 3)) wait = const Duration(seconds: 3);
    }
    return 0;
  }

  /// Redeems a Google Play purchase token for a credit pack (server verifies with Google).
  ///
  /// Throws on transient or verification failures, where the purchase must be left pending and
  /// retried rather than consumed — consuming one the server has not credited charges the user
  /// for nothing.
  /// Nothing is caught here: every failure reaches the caller, which decides whether to consume.
  /// That includes a 409, which means a concurrent writer — the refund webhook, or another
  /// delivery of the same purchase — is mid-grant. It is transient, so leaving the purchase
  /// pending lets the next delivery take the server's already-granted path and return a clean
  /// 200. Treating a 409 as success is what used to consume purchases credited to a session this
  /// device no longer held.
  Future<RedeemResult> redeemPurchase(String purchaseToken, String productId) async {
    final res = await _dio.post('${Constants.baseUrl}/credits/purchase',
        data: {'purchaseToken': purchaseToken, 'productId': productId});
    final data = (res.data['data'] as Map).cast<String, dynamic>();
    _balance = (data['credits'] as num).toInt();
    notifyListeners();
    // Defaulted rather than required: a 200 from this endpoint has always meant the caller was
    // credited, and the server now guarantees it — ownership is the caller by construction. The
    // flags are still read so a future server that qualifies a 200 is obeyed, not assumed away.
    return RedeemResult(
      balance: _balance,
      creditedToCaller: data['creditedToCaller'] as bool? ?? true,
      alreadyGranted: data['alreadyGranted'] as bool? ?? false,
    );
  }

  /// Drops the cached balance when the signed-in identity changes.
  ///
  /// Without it the figure on screen stays the previous account's until something happens to
  /// refetch — which is how a brand-new guest could be shown the credits of the account it had
  /// just replaced.
  void clearForIdentityChange() {
    if (_balance == 0) return;
    _balance = 0;
    notifyListeners();
  }
}

/// What redeeming a purchase did, from the caller's point of view.
class RedeemResult {
  /// The caller's balance afterwards, or -1 when the server did not say.
  final int balance;

  /// Whether the credits belong to the account that called. False means the purchase is owned by
  /// another account: the caller's balance did not rise and it must not act as though it had.
  final bool creditedToCaller;

  /// The token had already been redeemed, so this call granted nothing.
  final bool alreadyGranted;

  const RedeemResult({
    required this.balance,
    required this.creditedToCaller,
    required this.alreadyGranted,
  });
}


/// One row of the server's tool price table.
///
/// Mirrors ToolCreditCost on the backend, including the size component — the client used
/// to keep only `baseCredits`, so any size-priced tool was quoted below what it charged.
class ToolCost {
  final String toolId;
  final int baseCredits;
  final String sizeUnit; // NONE | BYTES
  final int creditsPerUnit;
  final int unitSize;

  const ToolCost({
    required this.toolId,
    required this.baseCredits,
    required this.sizeUnit,
    required this.creditsPerUnit,
    required this.unitSize,
  });

  factory ToolCost.fromJson(Map<String, dynamic> json) => ToolCost(
        toolId: json['toolId'] as String,
        baseCredits: (json['baseCredits'] as num?)?.toInt() ?? 0,
        sizeUnit: (json['sizeUnit'] as String?) ?? 'NONE',
        creditsPerUnit: (json['creditsPerUnit'] as num?)?.toInt() ?? 0,
        unitSize: (json['unitSize'] as num?)?.toInt() ?? 1,
      );

  bool get hasSizeComponent =>
      sizeUnit == 'BYTES' && creditsPerUnit > 0 && unitSize > 0;

  /// Same arithmetic the server applies, so the quote matches the charge.
  int costFor(int sizeBytes) {
    if (!hasSizeComponent || sizeBytes <= 0) return baseCredits;
    return baseCredits + (sizeBytes ~/ unitSize) * creditsPerUnit;
  }
}
