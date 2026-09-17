/// Numeric position and size for one field, in PDF points or millimetres.
///
/// Until this existed there was no number anywhere in the editor describing a field's geometry:
/// a field was whatever size the drag happened to leave it. That is fine for a signature box
/// and useless for the job people actually bring to a form editor — putting a checkbox exactly
/// on top of the box already printed on a bank form, which is a specific number of points wide.
///
/// The values shown are the same multiplication `AcroFormSpecMapper` performs
/// (`points = fraction x pageSize`), so what is typed here is what the backend receives.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_craft/l10n/l10n.dart';

/// Points per millimetre: 72 points to the inch, 25.4 mm to the inch.
const double _pointsPerMm = 72 / 25.4;

/// The unit the author is working in.
///
/// Points because that is the PDF's own unit and what a form's specification is written in;
/// millimetres because that is what someone measuring a printed page with a ruler has.
enum GeometryUnit {
  points,
  millimetres;

  double fromPoints(double points) =>
      this == GeometryUnit.points ? points : points / _pointsPerMm;

  double toPoints(double value) =>
      this == GeometryUnit.points ? value : value * _pointsPerMm;

  String label(BuildContext context) => this == GeometryUnit.points
      ? L10n.of(context).unitPoints
      : L10n.of(context).unitMillimetres;
}

class GeometryEditor extends StatefulWidget {
  /// The field's rectangle in PDF points.
  final Rect rectInPoints;

  /// Width and height move together (checkbox, radio).
  final bool lockAspect;

  /// Called with a new rectangle in PDF points.
  final ValueChanged<Rect> onChanged;

  /// Sizes of the other fields on this page, so one can be copied. Empty hides the control.
  final Map<String, Size> sizesOfOtherFields;

  const GeometryEditor({
    super.key,
    required this.rectInPoints,
    required this.lockAspect,
    required this.onChanged,
    this.sizesOfOtherFields = const {},
  });

  @override
  State<GeometryEditor> createState() => _GeometryEditorState();
}

class _GeometryEditorState extends State<GeometryEditor> {
  GeometryUnit _unit = GeometryUnit.points;

  late final _x = TextEditingController();
  late final _y = TextEditingController();
  late final _w = TextEditingController();
  late final _h = TextEditingController();

  /// One per box, so the editor can tell whether the author is mid-edit.
  ///
  /// While a box has focus its text is the source of truth and the model is downstream. Without
  /// this the host's clamp to a 4pt minimum rewrote the box on every keystroke: typing "18"
  /// into a 12pt field went 1 -> clamped to 4 -> "4.0" -> "4.18".
  late final _focus = {
    _x: FocusNode(),
    _y: FocusNode(),
    _w: FocusNode(),
    _h: FocusNode(),
  };

  bool get _editing => _focus.values.any((f) => f.hasFocus);

  /// True while a controller is being rewritten from the model, so the resulting `onChanged`
  /// is not fed straight back in as if the author had typed it.
  bool _syncing = false;

  /// The last rectangle this editor sent upwards.
  ///
  /// The host applies an edit, which comes back as a new [widget.rectInPoints], which would
  /// otherwise rewrite the boxes *while the author is still typing in them*: typing "18" into
  /// a 12pt field went 1 -> clamped -> re-synced -> "11.1". Recognising our own change and
  /// leaving the text alone is what makes the field typeable.
  Rect? _lastEmitted;

  @override
  void initState() {
    super.initState();
    _syncControllers();
    // On leaving a box, show the value the model actually settled on — the clamp to the page
    // and to the minimum size may have adjusted it, and silently disagreeing would be worse.
    for (final node in _focus.values) {
      node.addListener(() {
        if (!node.hasFocus && mounted) setState(_syncControllers);
      });
    }
  }

  @override
  void didUpdateWidget(GeometryEditor old) {
    super.didUpdateWidget(old);
    if (old.rectInPoints == widget.rectInPoints) return;
    // Mid-edit, or our own edit coming back: leave the boxes as typed.
    if (_editing) return;
    if (_lastEmitted != null && _closeEnough(_lastEmitted!, widget.rectInPoints)) return;
    _syncControllers();
  }

  /// Equal to within a twentieth of a point — the host clamps to the page and to a minimum
  /// size, so a value we sent can return very slightly changed without being a new edit.
  static bool _closeEnough(Rect a, Rect b) =>
      (a.left - b.left).abs() < 0.05 &&
      (a.top - b.top).abs() < 0.05 &&
      (a.width - b.width).abs() < 0.05 &&
      (a.height - b.height).abs() < 0.05;

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    _x.dispose();
    _y.dispose();
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _syncing = true;
    final r = widget.rectInPoints;
    _x.text = _fmt(r.left);
    _y.text = _fmt(r.top);
    _w.text = _fmt(r.width);
    _h.text = _fmt(r.height);
    _syncing = false;
  }

  /// One decimal is the useful precision: a point is already about a third of a millimetre, and
  /// more digits only make the boxes harder to read on a phone.
  String _fmt(double points) => _unit.fromPoints(points).toStringAsFixed(1);

  void _emit() {
    if (_syncing) return;
    final r = widget.rectInPoints;
    double read(TextEditingController c, double fallback) {
      final text = c.text.trim();
      // A half-typed value ("", ".", "1.") is not an edit yet — keep the current number rather
      // than pushing a zero the host would clamp, which then rewrote the box mid-keystroke.
      final parsed = text.isEmpty ? null : double.tryParse(text);
      return (parsed == null || parsed <= 0) ? fallback : _unit.toPoints(parsed);
    }

    var w = read(_w, r.width);
    var h = read(_h, r.height);
    if (widget.lockAspect) {
      // Whichever box the author edited wins; the other follows. Comparing against the current
      // rect tells us which one that was without tracking focus.
      final side = (w != r.width) ? w : h;
      w = side;
      h = side;
      // The height box is disabled when locked, so show the author what it became.
      if (!_focus[_h]!.hasFocus) {
        _syncing = true;
        _h.text = _unit.fromPoints(h).toStringAsFixed(1);
        _syncing = false;
      }
    }
    final next = Rect.fromLTWH(read(_x, r.left), read(_y, r.top), w, h);
    _lastEmitted = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final theme = Theme.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(l.geometryHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        SegmentedButton<GeometryUnit>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final unit in GeometryUnit.values)
              ButtonSegment(value: unit, label: Text(unit.label(context))),
          ],
          selected: {_unit},
          showSelectedIcon: false,
          onSelectionChanged: (sel) => setState(() {
            _unit = sel.first;
            _syncControllers();
          }),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _box(_x, l.geometryX)),
        const SizedBox(width: 8),
        Expanded(child: _box(_y, l.geometryY)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _box(_w, l.geometryWidth)),
        const SizedBox(width: 8),
        Expanded(child: _box(_h, l.geometryHeight, enabled: !widget.lockAspect)),
      ]),
      if (widget.lockAspect)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l.geometrySquareLocked,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          ]),
        ),
      if (widget.sizesOfOtherFields.isNotEmpty) ...[
        const SizedBox(height: 10),
        // Most forms repeat the same box: once one checkbox is the right size, the rest should
        // be that size without measuring again.
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: null,
          decoration: InputDecoration(
            isDense: true,
            labelText: l.geometryCopySizeFrom,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final entry in widget.sizesOfOtherFields.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  '${entry.key}  ·  ${_fmt(entry.value.width)} x ${_fmt(entry.value.height)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (name) {
            final size = widget.sizesOfOtherFields[name];
            if (size == null) return;
            final r = widget.rectInPoints;
            widget.onChanged(Rect.fromLTWH(r.left, r.top, size.width, size.height));
          },
        ),
      ],
    ]);
  }

  Widget _box(TextEditingController c, String label, {bool enabled = true}) => TextField(
        controller: c,
        focusNode: _focus[c],
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          suffixText: _unit.label(context),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _emit(),
      );
}
