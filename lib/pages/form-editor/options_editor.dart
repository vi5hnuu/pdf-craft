/// Editor for a dropdown or list field's choices.
library;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';

/// One row per choice, with add, remove and reorder.
///
/// Replaces a single comma-separated text box, which could not be reordered, showed all the
/// choices crushed into one line, and broke outright on any label containing a comma —
/// "Mumbai, Maharashtra" silently became two options.
class OptionsEditor extends StatefulWidget {
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  const OptionsEditor({super.key, required this.options, required this.onChanged});

  @override
  State<OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<OptionsEditor> {
  late final List<String> _values = List<String>.from(widget.options);
  late final List<TextEditingController> _controllers =
      _values.map((v) => TextEditingController(text: v)).toList();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(
      _values.map((v) => v.trim()).where((v) => v.isNotEmpty).toList());

  void _add() {
    setState(() {
      _values.add('');
      _controllers.add(TextEditingController());
    });
    _emit();
  }

  void _removeAt(int i) {
    setState(() {
      _values.removeAt(i);
      _controllers.removeAt(i).dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(L10n.of(context).optionsTitle, style: theme.textTheme.bodySmall),
      const SizedBox(height: 4),
      for (int i = 0; i < _values.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _controllers[i],
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: L10n.of(context).optionHint(i + 1),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  _values[i] = v;
                  _emit();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              tooltip: L10n.of(context).removeOption,
              color: theme.colorScheme.error,
              onPressed: () => _removeAt(i),
            ),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(L10n.of(context).addOption),
          onPressed: _add,
        ),
      ),
    ]);
  }
}
