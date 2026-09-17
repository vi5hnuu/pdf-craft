import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The ad-free entitlement that the ad widgets read to suppress ads.
///
/// **The server owns this.** It used to be a plain local preference, which meant switching ads
/// off was a matter of editing shared preferences — the app trusted a value the user controlled.
/// `/credits/balance` now returns `ad_free` on every launch and that value wins.
///
/// The local copy remains, but only as an offline cache so a user who has paid still gets an
/// ad-free app on a plane. It is written exclusively from a server response, never from the UI.
class ProService extends ChangeNotifier {
  static final ProService _instance = ProService._();
  ProService._();
  factory ProService() => _instance;

  static const _key = 'is_pro';
  bool _isPro = false;
  bool get isPro => _isPro;

  /// Whether the value came from the server this session, as opposed to the offline cache.
  bool _verified = false;
  bool get isVerified => _verified;

  /// Loads the cached entitlement so the first frame is correct before the network answers.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Applies the entitlement reported by the server and caches it for offline use.
  ///
  /// Only [CreditService] calls this, from the `/credits/balance` response.
  Future<void> applyFromServer({required bool adFree}) async {
    _verified = true;
    if (_isPro == adFree) return;
    _isPro = adFree;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, adFree);
    notifyListeners();
  }
}
