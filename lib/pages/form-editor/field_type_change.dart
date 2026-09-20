/// Converting a placed field from one type to another.
///
/// The editor could only ever set a field's type at creation, so "I meant a checkbox, not a
/// radio" meant deleting and starting again — losing the name, the geometry, the label and any
/// rules along with it.
///
/// A type is not a label, though: it decides which of a field's other properties mean anything.
/// Re-tagging alone leaves a converted field carrying settings that are invisible in the
/// inspector and still serialized — a text field converted from a number keeps `min`/`max` that
/// nothing shows and the runtime still enforces; a radio converted to a checkbox keeps a `group`
/// that, for a non-grouped type, silently changes which PDF field it belongs to. So conversion
/// is a migration, and this is where it lives.
library;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/pages/form-editor/editor_field.dart';
import 'package:pdf_craft/pages/form-editor/form_field_type.dart';

/// What a conversion would throw away, in the author's words. Empty means lossless.
List<String> lossOfChangingType(BuildContext context, EditorField f, FieldType to) {
  final l = L10n.of(context);
  final from = f.type;
  final lost = <String>[];

  if (from.groupable && !to.groupable && f.group.isNotEmpty) lost.add(l.lostGroup);
  if (from.isToggle && !to.isToggle && f.checked) lost.add(l.lostChecked);
  if (from.hasOptions && !to.hasOptions && f.options.isNotEmpty) lost.add(l.lostOptions);
  if (from.hasValue && !to.hasValue) {
    if (f.minValue.isNotEmpty ||
        f.maxValue.isNotEmpty ||
        f.minLength.isNotEmpty ||
        f.validationPattern.isNotEmpty) {
      lost.add(l.lostRules);
    }
    if (f.calcRefs.isNotEmpty) lost.add(l.lostCalc);
  }
  // Number is the only type where min/max mean anything; leaving it strands them.
  if (from == FieldType.number &&
      to != FieldType.number &&
      (f.minValue.isNotEmpty || f.maxValue.isNotEmpty)) {
    lost.add(l.lostRules);
  }
  return lost.toSet().toList();
}

/// Rewrites [f] to be a [to] field, clearing whatever no longer applies.
///
/// [pagePoints] is the current page's size, needed because a toggle must come out square in
/// *points* — `lockAspect` is only consulted while a resize gesture is in flight and never
/// repairs an existing rectangle, so a text box converted to a checkbox would otherwise stay a
/// wide oblong with a circle drawn inside it.
void applyTypeChange(EditorField f, FieldType to, Size? pagePoints) {
  final from = f.type;
  if (from == to) return;

  // ── things that stop meaning anything ────────────────────────────────────────
  if (!to.groupable) {
    // Critical rather than cosmetic: for a grouped type the PDF field name is the *group*, so a
    // stale group on a non-grouped field silently reassigns it to a field it is not part of.
    f.group = '';
    f.exportValue = '';
  } else if (!from.groupable) {
    // Entering a groupable type from a plain one: it starts as its own question.
    f.group = '${to.wire}_group_${DateTime.now().millisecondsSinceEpoch}';
    f.exportValue = to.isGrouped ? 'option_1' : '';
  } else if (!to.isGrouped) {
    // radio → checkbox: the group survives as an editor grouping, but the export value was the
    // PDF on-state and the backend fixes a checkbox's at "Yes".
    f.exportValue = '';
  }

  if (!to.isToggle) f.checked = false;
  if (!to.hasOptions) f.options = const [];
  if (to != FieldType.listbox) f.multiSelect = false;
  if (to == FieldType.multiline) f.comb = false;
  if (to != FieldType.date) f.dateFormat = '';

  if (!to.hasValue) {
    f.value = '';
    f.fontSize = 0;
    f.maxLength = 0;
    f.comb = false;
    f.validationPattern = '';
    f.minLength = '';
    // Calculations are only offered for value-bearing fields, so leaving the refs behind would
    // keep a rule alive that the inspector no longer shows.
    f.calcRefs = const [];
    f.calcFields = '';
  }
  // min/max are number-only; anywhere else they are enforced invisibly.
  if (to != FieldType.number) {
    f.minValue = '';
    f.maxValue = '';
  }

  f.type = to;

  // ── geometry ────────────────────────────────────────────────────────────────
  if (to.lockAspect && pagePoints != null) {
    // Square in points, not in fractions: equal fractions on a non-square page are not a square.
    final wPt = f.rect.width * pagePoints.width;
    final hPt = f.rect.height * pagePoints.height;
    final sidePt = wPt < hPt ? wPt : hPt;
    final w = (sidePt / pagePoints.width).clamp(0.0, 1.0);
    final h = (sidePt / pagePoints.height).clamp(0.0, 1.0);
    f.rect = Rect.fromLTWH(
      f.rect.left.clamp(0.0, 1 - w),
      f.rect.top.clamp(0.0, 1 - h),
      w,
      h,
    );
  } else if (from.isToggle && !to.isToggle) {
    // An 18pt square is unusable as a text box, so give the new type its own default width
    // while keeping the corner the author placed.
    final size = to.defaultSizeOn(pagePoints);
    f.rect = Rect.fromLTWH(
      f.rect.left.clamp(0.0, 1 - size.width),
      f.rect.top.clamp(0.0, 1 - size.height),
      size.width,
      size.height,
    );
  }
}

/// Seeds [f]'s options from a radio group's captions when converting it to a choice field, so
/// "Savings / Current / Salary" survives becoming a dropdown instead of being retyped.
void seedOptionsFromGroup(EditorField f, Iterable<EditorField> siblings) {
  final labels = siblings
      .map((s) => s.label.isNotEmpty ? s.label : s.exportValue)
      .where((s) => s.isNotEmpty)
      .toList();
  if (labels.isNotEmpty) f.options = labels;
}

/// Types offered as conversion targets, grouped so the sensible swaps sit together.
const List<List<FieldType>> typeChangeGroups = [
  [FieldType.text, FieldType.multiline, FieldType.number, FieldType.email, FieldType.phone, FieldType.date],
  [FieldType.checkbox, FieldType.radio],
  [FieldType.dropdown, FieldType.listbox],
  [FieldType.signature],
];
