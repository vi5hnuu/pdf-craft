import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the most recently used tools (by [ToolDef.id]) so the Tools screen
/// can surface a "Recently used" shortcut row.
///
/// Stored as an ordered list of tool ids, most-recent first, capped at
/// [_maxRecents]. Extends [ChangeNotifier] so the row can rebuild live when a
/// tool is launched. Mirrors the simple SharedPreferences pattern used by
/// FavoritesService.
class RecentToolsService extends ChangeNotifier {
  static final RecentToolsService _instance = RecentToolsService._();
  RecentToolsService._();
  factory RecentToolsService() => _instance;

  static const _key = 'recent_tool_ids';
  static const _maxRecents = 8;

  Future<List<String>> getRecentToolIds() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_key) ?? []);
  }

  /// Records [toolId] as the most recently used (moves it to the front).
  Future<void> record(String toolId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(prefs.getStringList(_key) ?? []);
    ids.remove(toolId); // de-dupe so it moves to front
    ids.insert(0, toolId);
    if (ids.length > _maxRecents) ids.removeRange(_maxRecents, ids.length);
    await prefs.setStringList(_key, ids);
    notifyListeners();
  }
}
