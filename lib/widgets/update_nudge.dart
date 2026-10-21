import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/pages/update_required_screen.dart';
import 'package:pdf_craft/singletons/app_config_service.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The soft counterpart to [UpdateRequiredScreen]: a dismissible nudge when a newer build exists.
///
/// It earns its place by making the hard gate rarer. A gate is the only lever that works on an
/// install already in the wild, and it is a blunt one — it stops the app dead. Nudging while an
/// old build still works is what keeps the number of installs that ever have to be gated small.
///
/// Dismissible on purpose, and quiet on purpose. A nudge that returns on every launch is read as
/// a nag and trains people to dismiss it without looking, which costs the gate its credibility
/// too. So: at most once per cool-off, and the clock is per recommended build, so a genuinely new
/// release may ask again while the same one may not.
class UpdateNudge {
  UpdateNudge._();

  static const _lastShownKey = 'update_nudge_last_shown';
  static const _lastShownBuildKey = 'update_nudge_last_build';

  /// How long to stay quiet after asking about a given build.
  ///
  /// Not server-tuned, unlike the gate and the rating thresholds. Those are levers that have to
  /// be changed from outside a release; the politeness of an optional nudge is not — and another
  /// column would have to be read by every launch of every install to carry it.
  static const _coolOff = Duration(days: 7);

  /// Shown once per app run at most, so returning to the home tab does not re-ask.
  static bool _askedThisSession = false;

  /// Whether the cool-off has passed, free of I/O so it can be tested directly.
  ///
  /// The clock is per build: the same recommended build may not ask again inside the cool-off,
  /// while a genuinely newer one may ask straight away — which is the behaviour anyone would
  /// expect, and the reason the build number is stored alongside the timestamp.
  static bool shouldShow({
    required int recommendedBuild,
    int? lastShownBuild,
    int? lastShownMs,
    required DateTime now,
  }) {
    if (lastShownMs == null) return true;
    if (lastShownBuild != recommendedBuild) return true;
    return now.difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs)) >= _coolOff;
  }

  /// Shows the nudge if the server recommends an update and the cool-off has passed.
  ///
  /// Never throws: this is an optional courtesy and must not be able to interfere with the
  /// screen that hosts it.
  static Future<void> maybeShow(BuildContext context) async {
    if (_askedThisSession) return;
    final config = AppConfigService().config;
    // updateRequired has its own full-screen route; a dialog on top of it would be noise.
    if (!config.updateRecommended || config.updateRequired) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!shouldShow(
        recommendedBuild: config.recommendedBuild,
        lastShownBuild: prefs.getInt(_lastShownBuildKey),
        lastShownMs: prefs.getInt(_lastShownKey),
        now: DateTime.now(),
      )) {
        return;
      }

      _askedThisSession = true;
      // Recorded before showing, not after: if the dialog is dismissed by a route change or the
      // app is killed while it is up, the cool-off should still apply. Asking again a week later
      // is a better failure than asking again in a second.
      await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_lastShownBuildKey, config.recommendedBuild);

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.system_update_outlined),
          title: Text(L10n.of(dialogContext).updateAvailableTitle),
          // Deliberately not config.updateMessage: that column is the gate's copy, written to
          // explain why a build has been withdrawn, and the same sentence shown as an optional
          // nudge either alarms the reader or reads as nonsense. One server message cannot serve
          // both tones, so the optional ask keeps its own wording.
          content: Text(L10n.of(dialogContext).updateAvailableBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(L10n.of(dialogContext).updateLater),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openStoreListing(config.storeUrl);
              },
              child: Text(L10n.of(dialogContext).updateNowAction),
            ),
          ],
        ),
      );
    } catch (e) {
      LoggerSingleton().logger.w('Update nudge skipped: $e');
    }
  }
}
