import 'package:flutter/material.dart';

/// Result of [ConfirmDialog.show].
class ConfirmResult {
  /// True when the user tapped the confirm button.
  final bool confirmed;

  /// True when the "don't ask again" checkbox was ticked (only meaningful when
  /// the dialog was shown with [showDontAskAgain] = true).
  final bool dontAskAgain;

  const ConfirmResult(this.confirmed, this.dontAskAgain);
}

/// A single reusable confirmation dialog used for:
///  - destructive actions (delete, overwrite) — pass [destructive] = true for a
///    red, warning-styled confirm button and icon.
///  - informational "are you sure / do you want to continue" prompts that can
///    optionally carry a "don't ask again" checkbox (pass [showDontAskAgain]).
///
/// Centralising this avoids the ad-hoc, inconsistent AlertDialogs that were
/// scattered across screens.
class ConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final bool showDontAskAgain;
  final IconData? icon;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.showDontAskAgain = false,
    this.icon,
  });

  /// Shows the dialog and resolves to a [ConfirmResult]. Returns a result with
  /// `confirmed == false` if dismissed by tapping outside / back.
  static Future<ConfirmResult> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    bool showDontAskAgain = false,
    IconData? icon,
  }) async {
    final result = await showDialog<ConfirmResult>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        showDontAskAgain: showDontAskAgain,
        icon: icon,
      ),
    );
    return result ?? const ConfirmResult(false, false);
  }

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        widget.destructive ? theme.colorScheme.error : theme.colorScheme.primary;

    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon ??
                (widget.destructive ? Icons.warning_amber_rounded : Icons.help_outline),
            color: accent,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(widget.title, textAlign: TextAlign.center),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message, textAlign: TextAlign.center),
          if (widget.showDontAskAgain) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _dontAskAgain,
              onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text("Don't ask me again"),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ConfirmResult(false, _dontAskAgain)),
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          style: widget.destructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () =>
              Navigator.of(context).pop(ConfirmResult(true, _dontAskAgain)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
