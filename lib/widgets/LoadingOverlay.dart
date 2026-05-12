import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf_craft/models/HttpState.dart';

/// Full-screen overlay that shows upload progress or a spinner.
/// Place as the last child of a Stack that covers the whole screen.
class LoadingOverlay extends StatelessWidget {
  final HttpState? httpState;

  const LoadingOverlay({super.key, required this.httpState});

  @override
  Widget build(BuildContext context) {
    if (httpState?.loading != true) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final progress = httpState?.progress;

    return Container(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.88),
      child: Center(
        child: progress != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              )
            : SpinKitThreeBounce(color: primary, size: 40),
      ),
    );
  }
}
