import 'package:flutter/widgets.dart';

/// The app's spacing scale, in one place.
///
/// Tool bodies were padded at 4, 8, 12, 16, 20, 24 and 32dp depending on which screen you were
/// on — 16 being the informal default, used by 24 of them — so moving between two tools visibly
/// shifted the content column. This is [AppRadius]'s counterpart for the other axis.
///
/// App-shell screens (splash, account, the Drive browser) keep their own deliberate padding;
/// this is the tool-screen scale.
class AppSpacing {
  AppSpacing._();

  /// Outer padding of a tool screen's body.
  static const double screen = 16;

  /// Between major blocks within a screen.
  static const double section = 24;

  /// Between a label and its control, or two rows of the same group.
  static const double item = 12;

  /// Inside a chip, badge or dense list row.
  static const double tight = 8;

  static const EdgeInsets screenPadding = EdgeInsets.all(screen);
}
