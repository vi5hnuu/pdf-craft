import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf_craft/models/HttpState.dart';

/// Full-screen, branded processing overlay driven by an [HttpState].
///
/// Replaces the bare three-dot spinner with a contextual, staged experience:
///   • upload progress (determinate) while the file is being sent,
///   • an indeterminate "working on it" state while the server processes,
///   • an optional [onCancel] action wired to the request's CancelToken,
///   • a one-line reassurance about how the file is handled.
///
/// Place as the last child of a [Stack] that covers the whole screen.
class ProcessingOverlay extends StatelessWidget {
  final HttpState? httpState;

  /// Short verb phrase for the current tool, e.g. "Compressing your PDF".
  final String? label;

  /// When provided, shows a Cancel button. Should cancel the in-flight request.
  final VoidCallback? onCancel;

  const ProcessingOverlay({
    super.key,
    required this.httpState,
    this.label,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (httpState?.loading != true) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final progress = httpState?.progress;

    // Derive a stage from the upload progress: no progress yet OR fully
    // uploaded means the server is doing the work; in-between is the upload.
    final uploading = progress != null && progress < 1.0;
    final stageText = uploading
        ? 'Uploading ${(progress * 100).toInt()}%'
        : 'Processing on our servers…';

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinKitFadingCube(color: primary, size: 34),
              const SizedBox(height: 20),
              Text(
                label ?? 'Working on it',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                stageText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  // Determinate while uploading; indeterminate while the server works.
                  value: uploading ? progress : null,
                  minHeight: 5,
                  backgroundColor: primary.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Sent securely · removed after processing',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    ),
                  ),
                ],
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
