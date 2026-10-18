import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf_craft/singletons/dio_singleton.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration the server owns and this app reads at launch: which builds are still supported,
/// and how often a rating may be asked for.
///
/// Nothing here ever blocks the app on its own. The update gate is the only feature in the app
/// that can make every install unusable at once, and a backend outage, a DNS failure or a bad row
/// in a table could all reach it — so a missing or failed answer means *no* gate, a cached answer
/// is preferred to none, and [updateRequired] is only ever true because the server explicitly and
/// successfully said so.
class AppConfigService extends ChangeNotifier {
  AppConfigService._();

  static final AppConfigService _instance = AppConfigService._();

  factory AppConfigService() => _instance;

  static const _cacheKey = 'app_config_cache_v1';

  final _dio = DioSingleton().dio;

  AppConfig _config = AppConfig.unrestricted;
  int _installedBuild = -1;

  AppConfig get config => _config;

  /// The running build number, or -1 before [load] has read it.
  int get installedBuild => _installedBuild;

  /// Fetches the config, falling back to the last cached copy and then to "nothing enforced".
  ///
  /// Safe to call more than once; the launch path calls it before navigating and the resume path
  /// calls it again.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Seed from cache first, so a slow or failed fetch still has the last known answer rather
    // than silently reverting to unrestricted.
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _config = AppConfig.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        await prefs.remove(_cacheKey); // unreadable cache is worse than none
      }
    }

    try {
      final info = await PackageInfo.fromPlatform();
      _installedBuild = int.tryParse(info.buildNumber) ?? -1;
    } catch (e) {
      // Cannot read our own build: send -1, which the server treats as ungated.
      LoggerSingleton().logger.w('Could not read package info: $e');
      _installedBuild = -1;
    }

    try {
      final res = await _dio.get(
        '${Constants.baseUrl}/app-config',
        queryParameters: {
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'build': _installedBuild,
        },
        // Unauthenticated by design, and the interceptor must not try to establish a session
        // for it: at launch that would race the very thing this call exists to gate.
        options: Options(extra: {'skipAuth': true}),
      );
      final data = (res.data['data'] as Map).cast<String, dynamic>();
      _config = AppConfig.fromJson(data);
      await prefs.setString(_cacheKey, jsonEncode(data));
      notifyListeners();
    } catch (e) {
      // Deliberately swallowed. Whatever went wrong, it must not stop the app starting.
      LoggerSingleton().logger.w('App config unavailable, using ${cached != null ? 'cache' : 'defaults'}: $e');
    }
  }
}

/// A snapshot of the server's launch configuration.
class AppConfig {
  /// This build is below the supported minimum and must not continue.
  final bool updateRequired;

  /// A newer build exists; worth a dismissible nudge.
  final bool updateRecommended;

  /// Copy for the gate, or null to use the app's own wording.
  final String? updateMessage;

  /// Where the Update button goes, or null to fall back to the store listing.
  final String? storeUrl;

  final int ratingMinSuccesses;
  final int ratingMinDaysInstalled;
  final int ratingMinDaysBetweenAsks;

  const AppConfig({
    required this.updateRequired,
    required this.updateRecommended,
    this.updateMessage,
    this.storeUrl,
    required this.ratingMinSuccesses,
    required this.ratingMinDaysInstalled,
    required this.ratingMinDaysBetweenAsks,
  });

  /// What the app assumes when the server has not been heard from: no gate, no nudge, and
  /// rating thresholds conservative enough to be harmless.
  static const unrestricted = AppConfig(
    updateRequired: false,
    updateRecommended: false,
    ratingMinSuccesses: 3,
    ratingMinDaysInstalled: 3,
    ratingMinDaysBetweenAsks: 60,
  );

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        // Every flag defaults to the permissive value, so a malformed or partial payload can
        // never be the reason someone is locked out.
        updateRequired: json['updateRequired'] as bool? ?? false,
        updateRecommended: json['updateRecommended'] as bool? ?? false,
        updateMessage: json['updateMessage'] as String?,
        storeUrl: json['storeUrl'] as String?,
        ratingMinSuccesses: (json['ratingMinSuccesses'] as num?)?.toInt() ?? 3,
        ratingMinDaysInstalled: (json['ratingMinDaysInstalled'] as num?)?.toInt() ?? 3,
        ratingMinDaysBetweenAsks: (json['ratingMinDaysBetweenAsks'] as num?)?.toInt() ?? 60,
      );
}
