/// The field types the editor offers, and their presentation.
///
/// Behaviour (sizes, flags, formats) comes from the engine registry; this layer holds only
/// what the UI needs — icon and localized label — so adding a type stays a one-line change.
library;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:form_engine/form_engine.dart' as engine;

enum FieldType { text, multiline, number, email, phone, checkbox, radio, dropdown, listbox, date, signature }

extension FieldTypeX on FieldType {
  String get label => switch (this) {
        FieldType.text => 'Text',
        FieldType.multiline => 'Paragraph',
        FieldType.number => 'Number',
        FieldType.email => 'Email',
        FieldType.phone => 'Phone',
        FieldType.listbox => 'List',
        FieldType.checkbox => 'Checkbox',
        FieldType.radio => 'Radio',
        FieldType.dropdown => 'Dropdown',
        FieldType.date => 'Date',
        FieldType.signature => 'Signature',
      };
  /// Localized label for the UI; `label` above stays English for logs and wire use.
  String localizedLabel(BuildContext context) => switch (this) {
        FieldType.text => L10n.of(context).fieldText,
        FieldType.multiline => L10n.of(context).fieldParagraph,
        FieldType.number => L10n.of(context).fieldNumber,
        FieldType.email => L10n.of(context).fieldEmail,
        FieldType.phone => L10n.of(context).fieldPhone,
        FieldType.listbox => L10n.of(context).fieldList,
        FieldType.checkbox => L10n.of(context).fieldCheckbox,
        FieldType.radio => L10n.of(context).fieldRadio,
        FieldType.dropdown => L10n.of(context).fieldDropdown,
        FieldType.date => L10n.of(context).fieldDate,
        FieldType.signature => L10n.of(context).fieldSignature,
      };
  IconData get icon => switch (this) {
        FieldType.text => Icons.text_fields,
        FieldType.multiline => Icons.notes,
        FieldType.number => Icons.pin_outlined,
        FieldType.email => Icons.alternate_email,
        FieldType.phone => Icons.phone_outlined,
        FieldType.listbox => Icons.list_alt_outlined,
        FieldType.checkbox => Icons.check_box_outlined,
        FieldType.radio => Icons.radio_button_checked,
        FieldType.dropdown => Icons.arrow_drop_down_circle_outlined,
        FieldType.date => Icons.calendar_today_outlined,
        FieldType.signature => Icons.draw_outlined,
      };
  String get wire => switch (this) {
        FieldType.text => 'text',
        FieldType.multiline => 'multiline',
        FieldType.number => 'number',
        FieldType.email => 'email',
        FieldType.phone => 'phone',
        FieldType.listbox => 'listbox',
        FieldType.checkbox => 'checkbox',
        FieldType.radio => 'radio',
        FieldType.dropdown => 'dropdown',
        FieldType.date => 'date',
        FieldType.signature => 'signature',
      };

  // ── Per-type behaviour comes from the engine's registry ──────────────────────
  // The enum stays as the UI's handle, but every behavioural question is answered
  // by the registered descriptor, so a type's rules live in exactly one place and
  // are unit-tested in `packages/form_engine` without a device.
  engine.FieldTypeDescriptor get _descriptor => formFieldTypes[wire];

  Size get defaultSize => Size(_descriptor.defaultSize.width, _descriptor.defaultSize.height);

  /// Width and height are tied together, so the field can only be square (checkbox, radio).
  bool get lockAspect => _descriptor.lockAspect;

  /// The type's default size as a fraction of a page [pagePoints] in size.
  ///
  /// Types with an absolute size — a checkbox is 12pt whatever the paper — are converted from
  /// points here, so the same field is the same physical size on A4 and on Letter.
  Size defaultSizeOn(Size? pagePoints) {
    final points = _descriptor.defaultPointSize;
    if (points == null || pagePoints == null) return defaultSize;
    final fraction = points.toFraction(pagePoints.width, pagePoints.height);
    return Size(fraction.width, fraction.height);
  }
  bool get isToggle => _descriptor.isToggle;
  bool get hasOptions => _descriptor.acceptsOptions;
  bool get hasValue => _descriptor.acceptsValue;
  bool get isGrouped => _descriptor.isGrouped;
}

/// The field types this app offers. Built once; the engine's registry owns the
/// per-type rules and this is simply the app's handle to it.
final engine.FieldTypeRegistry formFieldTypes =
    engine.FieldTypeRegistry(engine.builtinFieldTypes);
