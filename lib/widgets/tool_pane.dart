import 'package:flutter/material.dart';
import 'package:pdf_craft/utils/responsive.dart';

/// Centres a tool screen's content and caps its width on anything wider than a phone.
///
/// Wraps the whole `Scaffold` body, sticky action bar included, so the bar stays under the column
/// it belongs to instead of stretching away from it.
///
/// Measures its own constraints rather than the window: a [NavigationRail] takes about 80dp, so an
/// 840dp window leaves ~760dp here, and asking `MediaQuery` would decide for space this does not
/// occupy.
class ToolPane extends StatelessWidget {
  final Widget child;

  /// Whether this screen's content is a page canvas rather than a column of controls.
  ///
  /// [kMaxToolContentWidth] is a readability limit for form fields: a line of input wider than
  /// about 720dp is harder to scan, not easier. A page being annotated, cropped or laid out with
  /// form fields is the opposite — it wants every pixel available, and capping it rendered a
  /// 720dp page on a 1280dp tablet with ~280dp of dead margin on each side. The flag lives here
  /// rather than in a second widget so there is one place that decides.
  final bool canvas;

  const ToolPane({super.key, required this.child, this.canvas = false});

  @override
  Widget build(BuildContext context) {
    if (canvas) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (windowSizeFor(constraints.maxWidth) == WindowSize.compact) return child;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxToolContentWidth),
            child: child,
          ),
        );
      },
    );
  }
}
