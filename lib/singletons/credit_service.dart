import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf_craft/singletons/auth_service.dart';
import 'package:pdf_craft/singletons/dio_singleton.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
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
      _balance = (res.data['data']['credits'] as num).toInt();
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
  /// Returns `true` when the purchase is credited **or was already credited** (HTTP 409) —
  /// i.e. it is safe to *finalize/consume* the purchase. Throws on transient or
  /// verification failures, where the purchase should be left pending and retried later
  /// (never consumed, or the user would be charged with no credits).
  Future<bool> redeemPurchase(String purchaseToken, String productId) async {
    try {
      final res = await _dio.post('${Constants.baseUrl}/credits/purchase',
          data: {'purchaseToken': purchaseToken, 'productId': productId});
      _balance = (res.data['data']['credits'] as num).toInt();
      notifyListeners();
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Already redeemed (e.g. a redelivered purchase) — the credits exist; finalize it.
        refreshBalance();
        return true;
      }
      rethrow; // transient / verification failure → keep pending, retry
    }
  }
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
