import 'package:flutter/material.dart';

/// Success, warning and info colours, which [ColorScheme] does not define.
///
/// Material 3 gives a role for *error* and nothing for the other three states, so every screen
/// that needed one reached for `Colors.green` / `Colors.orange` / `Colors.blue` directly. Those
/// are mid-tone palette colours tuned to sit on a dark surface: measured against the light
/// theme's white card they land at 2.0–2.8:1, so the security scanner's severity chips, the
/// batch-process status icons and ten snackbar variants were all unreadable in light mode.
///
/// Each value here clears 4.5:1 against its own theme's surface as text, so the same token works
/// for a label, an icon and a 12%-alpha chip wash. Read it with [of].
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color warning;
  final Color info;

  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
  });

  /// Darkened from the Material palette so they stay legible on white.
  static const light = AppSemanticColors(
    success: Color(0xFF146C2E),
    warning: Color(0xFF8A5000),
    info: Color(0xFF0B5FA4),
  );

  /// Lightened for the same reason, against #1A1A1A.
  static const dark = AppSemanticColors(
    success: Color(0xFF6FD08C),
    warning: Color(0xFFFFB95C),
    info: Color(0xFF7FC4FF),
  );

  /// Falls back to [light] rather than returning null, so a widget built outside the app's
  /// themes (a test harness, a plain MaterialApp) still renders readable colours.
  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ?? light;

  /// Text or icon colour that reads against [background].
  ///
  /// These accents are light in the dark theme and dark in the light one, so a filled surface
  /// painted with one cannot assume white on top.
  static Color onFilled(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : Colors.black;

  @override
  AppSemanticColors copyWith({Color? success, Color? warning, Color? info}) =>
      AppSemanticColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
      );

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
