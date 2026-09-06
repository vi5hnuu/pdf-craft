import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the "ad-free" entitlement flag that ad widgets read to suppress ads.
///
/// The real source of truth is moving to the backend credit/subscription system
/// (with auth) — once that lands, [setPro] will be driven by the server-verified
/// entitlement. For now it's a persisted local flag so ad-suppression is wired
/// and testable. Extends [ChangeNotifier] so ad widgets rebuild on change.
class ProService extends ChangeNotifier {
  static final ProService _instance = ProService._();
  ProService._();
  factory ProService() => _instance;

  static const _key = 'is_pro';
  bool _isPro = false;
  bool get isPro => _isPro;

  /// Loads the persisted entitlement (call once in main()).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Sets and persists the ad-free entitlement (called by the entitlement layer).
  Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    _isPro = value;
    notifyListeners();
  }
}
