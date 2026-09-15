import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's language choice.
enum AppLanguage { system, english, hindi }

/// Owns the app language — mirrors [ThemeManager]: a persisted choice exposed as a
/// [ChangeNotifier] so MaterialApp rebuilds live when it changes.
///
/// `system` follows the device language (Hindi if the device is set to Hindi, otherwise
/// English); `english` / `hindi` override it.
class LocaleManager extends ChangeNotifier with WidgetsBindingObserver {
  static final LocaleManager _instance = LocaleManager._();
  LocaleManager._();
  factory LocaleManager() => _instance;

  static const _key = 'app_language';

  /// Languages the app ships translations for.
  static const supportedLocales = [Locale('en'), Locale('hi')];

  AppLanguage _language = AppLanguage.system;
  AppLanguage get language => _language;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _language = AppLanguage.values.firstWhere(
      (l) => l.name == prefs.getString(_key),
      orElse: () => AppLanguage.system,
    );
    // Re-resolve when the device language changes while following the system.
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }

  /// Quick toggle used by the app-bar button: flips between English and Hindi.
  Future<void> toggleEnglishHindi() =>
      setLanguage(isHindi ? AppLanguage.english : AppLanguage.hindi);

  /// Explicit locale for MaterialApp, or null to let it follow the device.
  Locale? get locale => switch (_language) {
        AppLanguage.system => null,
        AppLanguage.english => const Locale('en'),
        AppLanguage.hindi => const Locale('hi'),
      };

  /// The locale actually in effect (used outside the widget tree and to pick fonts).
  Locale get resolvedLocale {
    final explicit = locale;
    if (explicit != null) return explicit;
    return PlatformDispatcher.instance.locale.languageCode == 'hi'
        ? const Locale('hi')
        : const Locale('en');
  }

  bool get isHindi => resolvedLocale.languageCode == 'hi';

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_language == AppLanguage.system) notifyListeners();
  }
}
