import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';

/// Stands in for an image that could not be decoded.
///
/// `Image.file` with no `errorBuilder` paints Flutter's own exception box — a grey rectangle
/// with red error text — or throws during build. The app's whole job is other people's files,
/// which can be deleted, moved or replaced while a tool is open, so every image read from disk
/// needs somewhere to land that is not that.
class BrokenImage extends StatelessWidget {
  const BrokenImage({super.key});

  /// Convenient as `errorBuilder: BrokenImage.builder`.
  static Widget builder(BuildContext context, Object error, StackTrace? stack) =>
      const BrokenImage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faded = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 32, color: faded),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                L10n.of(context).errImageUnreadable,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: faded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
