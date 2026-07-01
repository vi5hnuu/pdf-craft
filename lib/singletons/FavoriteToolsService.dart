import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the user's favourite tools (by [ToolDef.id]) so the Tools screen can
/// surface a pinned "Favourites" row and a per-card star toggle.
///
/// Keeps an in-memory cache so widgets can read [isFavorite] synchronously
/// during build; call [load] once (e.g. in the Tools screen's initState) before
/// relying on the cache. Extends [ChangeNotifier] so the UI rebuilds live on
/// toggle. Mirrors the SharedPreferences pattern used by [RecentToolsService].
class FavoriteToolsService extends ChangeNotifier {
  static final FavoriteToolsService _instance = FavoriteToolsService._();
  FavoriteToolsService._();
  factory FavoriteToolsService() => _instance;

  static const _key = 'favorite_tool_ids';

  final Set<String> _cache = {};
  bool _loaded = false;

  /// Loads favourites into the in-memory cache (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cache
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const []);
    _loaded = true;
    notifyListeners();
  }

  /// Favourite tool ids, insertion order preserved.
  List<String> get ids => _cache.toList(growable: false);

  bool isFavorite(String toolId) => _cache.contains(toolId);

  /// Toggles [toolId] and persists. Returns the new favourite state.
  Future<bool> toggle(String toolId) async {
    final prefs = await SharedPreferences.getInstance();
    final nowFavorite = !_cache.contains(toolId);
    if (nowFavorite) {
      _cache.add(toolId);
    } else {
      _cache.remove(toolId);
    }
    await prefs.setStringList(_key, _cache.toList());
    notifyListeners();
    return nowFavorite;
  }
}
