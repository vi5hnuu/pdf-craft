import 'package:flutter/material.dart';

/// A reusable single-field text-input dialog.
///
/// It is a StatefulWidget so it OWNS its [TextEditingController] and disposes it
/// in `State.dispose` (after the route is fully removed). Disposing a controller
/// inline right after `await showDialog` — while the field is still animating
/// out — triggers the "_dependents.isEmpty is not true" assertion; this widget
/// avoids that entirely. Returns the entered text on confirm, or null on cancel.
class InputDialog extends StatefulWidget {
  final String title;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String confirmLabel;
  final String cancelLabel;
  final String initial;

  const InputDialog({
    super.key,
    required this.title,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.confirmLabel = 'OK',
    this.cancelLabel = 'Cancel',
    this.initial = '',
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    String initial = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => InputDialog(
        title: title,
        label: label,
        hint: hint,
        obscure: obscure,
        keyboardType: keyboardType,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        initial: initial,
      ),
    );
  }

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.cancelLabel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
