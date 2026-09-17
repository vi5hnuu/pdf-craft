import 'package:flutter/widgets.dart';
import 'package:pdf_craft/l10n/locale_manager.dart';
import 'package:pdf_craft/l10n/generated/app_localizations.dart';

export 'package:pdf_craft/l10n/generated/app_localizations.dart';

/// Single entry point for translated strings.
///
/// - Widgets: `L10n.of(context).someKey` (rebuilds with the locale).
/// - Code without a BuildContext (snackbars raised from services, bloc error fallbacks, the
///   credit gate): `L10n.current.someKey`, resolved from [LocaleManager].
class L10n {
  L10n._();

  static AppLocalizations of(BuildContext context) => AppLocalizations.of(context);

  static AppLocalizations get current =>
      lookupAppLocalizations(LocaleManager().resolvedLocale);
}
