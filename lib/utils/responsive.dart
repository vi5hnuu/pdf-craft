import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

/// Material 3 window size classes.
enum WindowSize {
  compact,
  medium,
  expanded;

  bool atLeast(WindowSize other) => index >= other.index;
}

/// Navigation becomes a rail at this width.
const double kMediumWidth = 600;

/// Files splits into two panes at this width.
///
/// Not at [kMediumWidth]: a 600dp window split into a 380dp list and a 220dp preview gives a
/// preview too narrow to read.
const double kExpandedWidth = 840;

/// How wide a column of form controls may get. A readability limit, not a device size, so it does
/// not scale with the window.
const double kMaxToolContentWidth = 720;

WindowSize windowSizeFor(double width) {
  if (width >= kExpandedWidth) return WindowSize.expanded;
  if (width >= kMediumWidth) return WindowSize.medium;
  return WindowSize.compact;
}

/// Width a tool screen's content actually occupies — the window, capped where [kMaxToolContentWidth]
/// caps it.
///
/// For sizing a bitmap, where reading the window would over-measure: inside a constrained pane a
/// render bounded by screen width is decoded several times larger than it is drawn. Prefer
/// `LayoutBuilder` constraints when the call site is in `build`; this is for the ones that are not,
/// such as an async render that needs the figure before layout.
double toolContentWidthOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (windowSizeFor(width) == WindowSize.compact) return width;
  return width < kMaxToolContentWidth ? width : kMaxToolContentWidth;
}

/// Whether the device is tablet-shaped, independent of the current window.
///
/// Shortest side, so it does not flip with rotation or split-screen. Read from
/// [PlatformDispatcher] rather than a [MediaQuery] so it works before `runApp`.
bool get isTabletDevice {
  final view = PlatformDispatcher.instance.implicitView;
  if (view == null) return false;
  return (view.physicalSize / view.devicePixelRatio).shortestSide >= kMediumWidth;
}
