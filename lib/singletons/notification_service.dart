import 'package:flutter/material.dart';
import 'package:pdf_craft/theme/app_semantic_colors.dart';

/// What a snackbar is telling the user, so the colour is not the caller's problem.
///
/// The parameter used to be `MaterialColor color = Colors.red`, and because `MaterialColor` is a
/// narrower type than `Color`, no caller could pass `colorScheme.error` even if it wanted to.
/// Every site therefore passed a raw palette colour — 30 reds, 13 greens, 10 oranges — none of
/// which respond to the theme, and white-on-`Colors.orange` measures 2.16:1.
enum SnackKind { error, warning, success, info }

class NotificationService {
  //assign this key to topmost widget
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  NotificationService._();

  static get messengerKey => _scaffoldMessengerKey;

  /// Resolves [kind] against the live theme.
  ///
  /// Read from the messenger's own context rather than the caller's: most callers are blocs and
  /// services with no `BuildContext`, which is why they were passing literal colours.
  static Color _background(SnackKind kind) {
    final context = _scaffoldMessengerKey.currentContext;
    if (context == null) return const Color(0xFFB00020);
    final semantic = AppSemanticColors.of(context);
    return switch (kind) {
      SnackKind.error => Theme.of(context).colorScheme.error,
      SnackKind.warning => semantic.warning,
      SnackKind.success => semantic.success,
      SnackKind.info => semantic.info,
    };
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showSnackbar(
      {required String text,
      SnackKind kind = SnackKind.error,
      bool showCloseIcon = true,
      Duration? duration,
      SnackBarAction? action}) {
    _scaffoldMessengerKey.currentState?.clearSnackBars();
    final background = _background(kind);
    // The accents are light in the dark theme and dark in the light one, so the old
    // unconditional white text could not have read on both.
    final foreground = AppSemanticColors.onFilled(background);
    final snackbar = SnackBar(
      content: Text(text, style: TextStyle(color: foreground)),
      elevation: 5,
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      showCloseIcon: showCloseIcon,
      closeIconColor: foreground,
      // Give the user time to tap an action; otherwise keep it brief.
      duration: duration ?? (action != null ? const Duration(seconds: 4) : const Duration(seconds: 2)),
      action: action,
    );
    return _scaffoldMessengerKey.currentState?.showSnackBar(snackbar);
  }

  static hideSnacks(){
    _scaffoldMessengerKey.currentState?.clearSnackBars();
  }

}
