import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/singletons/DioSingleton.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/utils/Constants.dart';

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
      _loaded ? refreshBalance() : load();
    }
  }

  final _dio = DioSingleton().dio;

  int _balance = 0;
  Map<String, int> _costs = {}; // toolId -> base credit cost
  bool _loaded = false;
  String? _lastUserId;

  void _onAuthChanged() {
    final id = AuthService().user?.id;
    if (id != _lastUserId) {
      _lastUserId = id;
      refreshBalance(); // different account → its own balance
    }
  }

  int get balance => _balance;
  bool get loaded => _loaded;

  /// Base credit cost of a tool (0 = free). The server may add a size surcharge on
  /// very large inputs; this is the headline price shown in the UI.
  int costFor(String toolId) => _costs[toolId] ?? 0;
  bool isPaid(String toolId) => costFor(toolId) > 0;

  /// Loads balance + cost table. Safe to call at startup; failures are non-fatal.
  Future<void> load() async {
    await Future.wait([refreshBalance(), _loadCosts()]);
    _loaded = true;
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
        for (final row in list) row['toolId'] as String: (row['baseCredits'] as num).toInt()
      };
    } catch (e) {
      LoggerSingleton().logger.w('Costs fetch failed: $e');
    }
  }

  /// Claims the daily free allowance. Returns the granted amount (throws on 409 if already claimed).
  Future<int> claimDaily() async {
    final res = await _dio.post('${Constants.baseUrl}/credits/daily');
    _balance = (res.data['data']['credits'] as num).toInt();
    notifyListeners();
    return (res.data['data']['granted'] as num).toInt();
  }

  /// Grants rewarded-ad credits. [idempotencyKey] dedupes a single ad impression.
  Future<int> grantRewarded(String idempotencyKey) async {
    final res = await _dio.post('${Constants.baseUrl}/credits/rewarded',
        options: Options(headers: {'Idempotency-Key': idempotencyKey}));
    _balance = (res.data['data']['credits'] as num).toInt();
    notifyListeners();
    return (res.data['data']['granted'] as num).toInt();
  }

  /// Redeems a verified Google Play purchase token for a credit pack.
  Future<void> redeemPurchase(String purchaseToken, String productId) async {
    final res = await _dio.post('${Constants.baseUrl}/credits/purchase',
        data: {'purchaseToken': purchaseToken, 'productId': productId});
    _balance = (res.data['data']['credits'] as num).toInt();
    notifyListeners();
  }
}
