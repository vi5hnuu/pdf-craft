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

  const ToolPane({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
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
