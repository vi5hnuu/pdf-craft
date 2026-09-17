/// The per-field properties sheet: name, appearance, rules and logic.
library;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:form_engine/form_engine.dart' as engine;
import 'package:pdf_craft/pages/form-editor/editor_field.dart';
import 'package:pdf_craft/pages/form-editor/form_field_type.dart';

/// Properties editor for a single field, opened as a modal sheet. Owns its own
/// controllers (created from the field) so switching fields always shows the
/// correct values, and writes edits straight back to the [field].
class FieldInspector extends StatefulWidget {
  final EditorField field;

  /// Adds a sibling option to the selected field's group. The new option is linked but
  /// positioned freely, so it can be dragged next to whatever the document prints there.
  final void Function(EditorField source) onAddOption;

  /// How many options already share a group, so the sheet can say so.
  final int Function(String group) optionsInGroup;

  /// The group's letter as shown on the canvas badge, so the author can connect the two.
  final String Function(String group) groupLetter;

  /// Turns a field name typed by the author into a stable reference, resolved against the
  /// layout as it stands *now*. Doing this on entry rather than on save is what makes a
  /// later rename harmless.
  final engine.FieldRef Function(String name) resolve;

  const FieldInspector({super.key, 
    required this.field,
    required this.resolve,
    required this.onAddOption,
    required this.optionsInGroup,
    required this.groupLetter,
  });

  @override
  State<FieldInspector> createState() => _FieldInspectorState();
}

class _FieldInspectorState extends State<FieldInspector> {
  late final _name = TextEditingController(text: widget.field.name);
  late final _group = TextEditingController(text: widget.field.group);
  late final _export = TextEditingController(text: widget.field.exportValue);
  late final _options = TextEditingController(text: widget.field.options.join(', '));
  late final _value = TextEditingController(text: widget.field.value);
  late final _fontSize = TextEditingController(text: widget.field.fontSize > 0 ? widget.field.fontSize.toStringAsFixed(0) : '');
  late final _tooltip = TextEditingController(text: widget.field.tooltip);
  late final _maxLength = TextEditingController(text: widget.field.maxLength > 0 ? '${widget.field.maxLength}' : '');
  late final _pattern = TextEditingController(text: widget.field.validationPattern);
  late final _minValue = TextEditingController(text: widget.field.minValue);
  late final _maxValue = TextEditingController(text: widget.field.maxValue);
  late final _minLength = TextEditingController(text: widget.field.minLength);
  late final _condField = TextEditingController(text: widget.field.conditionField);
  late final _condValue = TextEditingController(text: widget.field.conditionValue);
  late final _calcFields = TextEditingController(text: widget.field.calcFields);

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    _export.dispose();
    _options.dispose();
    _value.dispose();
    _fontSize.dispose();
    _tooltip.dispose();
    _maxLength.dispose();
    _pattern.dispose();
    _minValue.dispose();
    _maxValue.dispose();
    _minLength.dispose();
    _condField.dispose();
    _condValue.dispose();
    _calcFields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = widget.field;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      // The sheet grew well past a phone screen once rules and logic moved in, so it scrolls
      // rather than overflowing.
      child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(f.type.icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(L10n.of(context).typeFieldLabel(f.type.localizedLabel(context)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        _field(_name, L10n.of(context).fieldName, (v) => f.name = v),
        if (f.type.isGrouped) ...[
          _field(_group, L10n.of(context).radioGroup, (v) => f.group = v),
          _field(_export, L10n.of(context).optionValue, (v) => f.exportValue = v),
          Row(children: [
            Expanded(
              child: Text(
                  L10n.of(context).groupBadgeAndCount(
                      widget.groupLetter(f.group), widget.optionsInGroup(f.group)),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(L10n.of(context).addOptionToGroup),
              onPressed: () {
                Navigator.pop(context);
                widget.onAddOption(f);
              },
            ),
          ]),
        ],
        if (f.type.hasOptions)
          _field(_options, L10n.of(context).optionsCommaSeparated,
              (v) => f.options = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
        if (f.type.hasValue) _field(_value, L10n.of(context).defaultValue, (v) => f.value = v),
        if (f.type.hasValue)
          _field(_fontSize, L10n.of(context).fontSizeAuto, (v) => f.fontSize = double.tryParse(v) ?? 0,
              keyboard: TextInputType.number),
        _field(_tooltip, L10n.of(context).fieldTooltip, (v) => f.tooltip = v),
        if (f.type.isToggle)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.type == FieldType.radio ? L10n.of(context).selectedByDefault : L10n.of(context).checkedByDefault),
            value: f.checked,
            onChanged: (v) => setState(() => f.checked = v),
          ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(L10n.of(context).required),
          value: f.required,
          onChanged: (v) => setState(() => f.required = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(L10n.of(context).fieldReadOnly),
          value: f.readOnly,
          onChanged: (v) => setState(() => f.readOnly = v),
        ),
        if (f.type == FieldType.listbox)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(L10n.of(context).fieldMultiSelect),
            value: f.multiSelect,
            onChanged: (v) => setState(() => f.multiSelect = v),
          ),

        // ── Appearance ────────────────────────────────────────────────────────────
        if (f.type.hasValue) ...[
          _sectionTitle(theme, L10n.of(context).sectionAppearance),
          _field(_maxLength, L10n.of(context).fieldMaxLength,
              (v) => f.maxLength = int.tryParse(v) ?? 0, keyboard: TextInputType.number),
          // Comb needs a character cap and a single line — offering it otherwise would let the
          // user set a flag the PDF spec makes the backend drop.
          if (f.maxLength > 0 && f.type != FieldType.multiline)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(L10n.of(context).fieldComb),
              value: f.comb,
              onChanged: (v) => setState(() => f.comb = v),
            ),
          const SizedBox(height: 4),
          Text(L10n.of(context).fieldAlignment, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SegmentedButton<engine.TextAlignment>(
            segments: [
              ButtonSegment(value: engine.TextAlignment.left, label: Text(L10n.of(context).alignLeft)),
              ButtonSegment(value: engine.TextAlignment.center, label: Text(L10n.of(context).alignCenter)),
              ButtonSegment(value: engine.TextAlignment.right, label: Text(L10n.of(context).alignRight)),
            ],
            selected: {f.alignment},
            onSelectionChanged: (sel) => setState(() => f.alignment = sel.first),
          ),
          _sectionTitle(theme, L10n.of(context).sectionRules),
          // A number field could not be bounded from the UI at all, even though the runtime has
          // always enforced min/max. Shown only for numbers, where a bound means something.
          if (f.type == FieldType.number) ...[
            Row(children: [
              Expanded(
                  child: _field(_minValue, L10n.of(context).fieldMinValue,
                      (v) => f.minValue = v, keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(
                  child: _field(_maxValue, L10n.of(context).fieldMaxValue,
                      (v) => f.maxValue = v, keyboard: TextInputType.number)),
            ]),
          ] else
            _field(_minLength, L10n.of(context).fieldMinLength,
                (v) => f.minLength = v, keyboard: TextInputType.number),
          _field(_pattern, L10n.of(context).fieldPattern, (v) => f.validationPattern = v),
          // Email and phone validate by type, which was invisible — the author could not tell
          // them apart from a plain Text field in the inspector.
          if (f.type == FieldType.email || f.type == FieldType.phone)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.verified_outlined, size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    L10n.of(context).fieldFormatBadge(f.type.localizedLabel(context)),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ]),
            ),
        ],

        // ── Logic ─────────────────────────────────────────────────────────────────
        _sectionTitle(theme, L10n.of(context).sectionLogic),
        Text(L10n.of(context).conditionShowWhen, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        _field(_condField, L10n.of(context).conditionFieldName, (v) {
          f.conditionField = v;
          final name = v.trim();
          f.conditionRef = name.isEmpty ? null : widget.resolve(name);
        }),
        DropdownButtonFormField<engine.ConditionOperator>(
          initialValue: f.conditionOperator,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          items: engine.ConditionOperator.values
              .map((o) => DropdownMenuItem(value: o, child: Text(_operatorLabel(context, o))))
              .toList(),
          onChanged: (v) => setState(() => f.conditionOperator = v ?? engine.ConditionOperator.equals),
        ),
        const SizedBox(height: 8),
        _field(_condValue, L10n.of(context).conditionValue, (v) => f.conditionValue = v),

        if (f.type.hasValue) ...[
          const SizedBox(height: 8),
          Text(L10n.of(context).calcTitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<engine.CalculationFunction>(
            initialValue: f.calcFunction,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: engine.CalculationFunction.values
                .map((c) => DropdownMenuItem(value: c, child: Text(_calcLabel(context, c))))
                .toList(),
            onChanged: (v) => setState(() => f.calcFunction = v ?? engine.CalculationFunction.sum),
          ),
          const SizedBox(height: 8),
          _field(_calcFields, L10n.of(context).calcFieldsHint, (v) {
            f.calcFields = v;
            f.calcRefs = v
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .map(widget.resolve)
                .toList();
          }),
        ],

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).done)),
        ),
      ]),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
      );

  String _operatorLabel(BuildContext context, engine.ConditionOperator o) => switch (o) {
        engine.ConditionOperator.equals => L10n.of(context).opEquals,
        engine.ConditionOperator.notEquals => L10n.of(context).opNotEquals,
        engine.ConditionOperator.contains => L10n.of(context).opContains,
        engine.ConditionOperator.isEmpty => L10n.of(context).opIsEmpty,
        engine.ConditionOperator.isNotEmpty => L10n.of(context).opIsNotEmpty,
        engine.ConditionOperator.greaterThan => L10n.of(context).opGreaterThan,
        engine.ConditionOperator.lessThan => L10n.of(context).opLessThan,
      };

  String _calcLabel(BuildContext context, engine.CalculationFunction c) => switch (c) {
        engine.CalculationFunction.sum => L10n.of(context).calcSum,
        engine.CalculationFunction.average => L10n.of(context).calcAverage,
        engine.CalculationFunction.product => L10n.of(context).calcProduct,
        engine.CalculationFunction.min => L10n.of(context).calcMin,
        engine.CalculationFunction.max => L10n.of(context).calcMax,
      };

  Widget _field(TextEditingController c, String label, ValueChanged<String> onChanged, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

