import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers what a tool was last set to.
///
/// Tools opened at their defaults every time, so applying the same watermark or header across a
/// set of documents meant retyping the whole configuration on each one. Settings are stored per
/// tool on the device and never leave it.
///
/// Never used for anything secret. A password is not a setting — it belongs to one document, and
/// keeping it would be storing a credential on disk. Nor is a page range: a range chosen for one
/// document means nothing in the next, so callers simply leave those out of what they save.
///
/// Mirrors the SharedPreferences shape of [RecentToolsService] and [FavoriteToolsService].
class ToolSettingsService extends ChangeNotifier {
  static final ToolSettingsService _instance = ToolSettingsService._();
  ToolSettingsService._();
  factory ToolSettingsService() => _instance;

  static const _prefix = 'tool_settings_';

  /// Bumped when a tool's stored shape changes.
  ///
  /// An older payload is discarded rather than merged, so a renamed or retyped field cannot
  /// resurface as an unreadable value in a live control.
  static const _version = 1;

  String _key(String toolId) => '$_prefix$toolId';

  /// Reads a tool's settings, or an empty map when there are none to read.
  ///
  /// Any failure — a shape change, corrupt JSON — yields an empty map, because remembering is a
  /// convenience and must never be able to stop a screen opening.
  Future<Map<String, dynamic>> load(String toolId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(toolId));
      if (raw == null) return const {};

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};
      if (decoded['version'] != _version) return const {};

      final values = decoded['values'];
      return values is Map<String, dynamic> ? values : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Stores a tool's settings, replacing whatever was there.
  Future<void> save(String toolId, Map<String, dynamic> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key(toolId), jsonEncode({'version': _version, 'values': values}));
      notifyListeners();
    } catch (_) {
      // Storage full or unavailable; the tool still works with what the user typed.
    }
  }

  /// Forgets a tool's settings, so it opens at its defaults again.
  Future<void> clear(String toolId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(toolId));
      notifyListeners();
    } catch (_) {
      // Nothing to do; the caller has already reset the live controls.
    }
  }

  /// Reads one value, falling back to [fallback] when it is missing or the wrong type.
  ///
  /// JSON gives back `int` for a whole number even where a `double` was written, which is the
  /// usual way a remembered slider position comes back unusable.
  static T read<T>(Map<String, dynamic> values, String key, T fallback) {
    final value = values[key];
    if (value is T) return value;
    if (fallback is double && value is num) return value.toDouble() as T;
    if (fallback is int && value is num) return value.toInt() as T;
    return fallback;
  }
}
