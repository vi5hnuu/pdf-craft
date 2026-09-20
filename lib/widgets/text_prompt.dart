/// Ask the user for a line (or a few lines) of text.
///
/// Exists because the obvious way to write this is wrong:
///
/// ```dart
/// final controller = TextEditingController(text: initial);
/// final value = await showDialog(...);
/// controller.dispose();          // ← too early
/// ```
///
/// `showDialog` completes as soon as the result is available, but the dialog route is still
/// animating out and its `TextField` is still mounted and listening. Disposing the controller
/// there throws "A TextEditingController was used after being disposed", and the framework then
/// fails a second assertion while tearing the subtree down — which is what actually reaches the
/// user, as a red screen with no mention of a text field.
///
/// Here the dialog owns its controller and releases it in its own `dispose`, which runs when the
/// route is genuinely gone.
library;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';

/// Shows a prompt and returns the trimmed text, or null if the user cancelled or left it empty.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? label,
  String? helperText,
  String? confirmLabel,
  int maxLines = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextPromptDialog(
      title: title,
      initial: initial,
      label: label,
      helperText: helperText,
      confirmLabel: confirmLabel ?? L10n.of(ctx).ok,
      maxLines: maxLines,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.label,
    required this.helperText,
    required this.confirmLabel,
    required this.maxLines,
  });

  final String title;
  final String initial;
  final String? label;
  final String? helperText;
  final String confirmLabel;
  final int maxLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    // Runs when the route has actually been removed, not when its result was delivered.
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.maxLines,
          minLines: 1,
          textInputAction:
              widget.maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
          onSubmitted: widget.maxLines > 1 ? null : (_) => _submit(),
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.helperText!,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context).cancel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
