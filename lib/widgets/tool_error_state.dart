import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';

/// What a tool shows when loading failed: an icon, the cause, and a way to try again.
///
/// Four screens rendered a failure as `Center(child: Icon(Icons.error, color: Colors.red))` and
/// nothing else — no message, no retry, and no way for the user to tell a corrupt PDF from a
/// dropped connection. The shape here is the one analyze-pdf and the inspectors already use;
/// this makes it the single copy of it.
///
/// [compact] is for a failure inside a list row or a thumbnail cell, where there is no room for
/// the full block but a reason is still owed.
class ToolErrorState extends StatelessWidget {
  final String? message;

  /// Omitted where the caller genuinely cannot retry — a page that failed to render inside an
  /// already-open document, for instance.
  final VoidCallback? onRetry;

  final bool compact;

  const ToolErrorState({super.key, this.message, this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message?.trim().isNotEmpty == true
        ? message!.trim()
        : L10n.of(context).toolErrorGeneric;

    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 20, color: theme.colorScheme.error),
            const SizedBox(height: 4),
            Text(text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(L10n.of(context).retry)),
          ],
        ]),
      ),
    );
  }
}
