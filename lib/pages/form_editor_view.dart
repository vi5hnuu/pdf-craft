import 'dart:io';
import 'dart:math' as math;
import 'package:pdf_craft/pages/form-editor/editor_field.dart';
import 'package:pdf_craft/pages/form-editor/field_inspector.dart';
import 'package:pdf_craft/pages/form-editor/field_list_sheet.dart';
import 'package:pdf_craft/pages/form-editor/field_appearance_painter.dart';
import 'package:pdf_craft/pages/form-editor/form_field_type.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/create_form.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'dart:async';

import 'package:form_engine/form_engine.dart' as engine;
import 'package:pdf_craft/services/forms/form_draft_store.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/theme/app_radius.dart';



/// Full PDF form builder: place text / paragraph / checkbox / radio / dropdown /
/// date / signature fields on any page, drag, resize & edit them, zoom in for
/// precision, then export a **real fillable** PDF.
class FormEditorView extends StatefulWidget {
  final File file;
  const FormEditorView({super.key, required this.file});

  @override
  State<FormEditorView> createState() => _FormEditorViewState();
}

class _FormEditorViewState extends State<FormEditorView>
    with ToolResultHandler, ToolViewMixin {
  PdfDocument? _doc;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfPageImage? _pageImage;
  bool _loadingPage = true;

  final Map<int, List<EditorField>> _pageFields = {};
  final Map<int, Size> _pagePoints = {};
  List<EditorField> get _fields => _pageFields[_currentPage] ??= [];

  String? _selectedId;
  int _autoName = 1;

  /// Snapshots of the whole layout, newest last.
  ///
  /// Placing and dragging fields is fiddly on a phone and a mistaken delete used to mean
  /// re-placing the field by hand. Encoded schemas are cheap and avoid any risk of the
  /// snapshot sharing mutable state with the live fields.
  final List<Map<String, Object?>> _undoStack = [];
  static const _maxUndo = 30;

  /// How far the canvas can be zoomed. A 12pt box is about 6 logical pixels at fit scale on a
  /// phone, so the old 5x ceiling left the author aiming at something they could not see.
  static const double _maxZoom = 12;

  /// Caption defaults, matched to the backend so the preview and the output agree.
  static const double _defaultLabelPoints = 9;
  static const double _labelGapPoints = 4;

  final TransformationController _tc = TransformationController();
  FormDraftStore? _drafts;

  /// Live "W x H pt" shown beside the field while it is being dragged or resized.
  ///
  /// Placement was entirely by eye: nothing in the editor ever said how big a field was, so
  /// matching the box already printed on a form was guesswork.
  String? _dragReadout;

  /// Hides all editing chrome so the canvas shows only what the produced PDF will contain.
  ///
  /// The chrome (type badge, group letter, name label, selection wash) is what makes a layout
  /// workable, but it also obscures the thing being placed. A toggle is the honest answer: edit
  /// with the aids on, check the result with them off, without leaving the screen.
  bool _previewMode = false;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _open();
  }

  /// Restores a layout left behind on a previous visit to this document.
  ///
  /// Placing fields is slow, deliberate work, so it is not thrown away when the
  /// editor closes. The draft is offered rather than applied silently: the user
  /// may well have come back to start over.
  Future<void> _restoreDraft() async {
    final store = _drafts = await FormDraftStore.forApp();
    final draft = await store.load(widget.file.path);
    if (draft == null || draft.fields.isEmpty || !mounted) return;

    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).formDraftFoundTitle),
        content: Text(L10n.of(ctx).formDraftFoundBody(draft.fields.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L10n.of(ctx).formDraftStartFresh),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(L10n.of(ctx).formDraftRestore),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (restore == true) {
      _applySchema(draft);
    } else {
      await store.delete(widget.file.path);
    }
  }

  /// Rebuilds the editor's fields from a stored schema.
  void _applySchema(engine.FormSchema schema) {
    setState(() {
      _pageFields.clear();
      // Page sizes travel with the draft. Without them `toSpecs` skips every field on a page
      // the author never opened this session (it cannot convert fractions to points without a
      // page size), so re-opening a multi-page draft and pressing Create silently dropped them.
      for (final entry in schema.pageSizes.entries) {
        _pagePoints.putIfAbsent(
            entry.key, () => Size(entry.value.width, entry.value.height));
      }
      for (final f in schema.fields) {
        final type = FieldType.values.firstWhere(
          (t) => t.wire == f.typeId,
          // A type this build does not know about (an older app opening a newer
          // draft) is skipped rather than crashing the editor.
          orElse: () => FieldType.text,
        );
        if (type.wire != f.typeId) continue;
        _pageFields.putIfAbsent(f.page, () => []).add(
              EditorField(type: type, rect: Rect.fromLTWH(f.rect.left, f.rect.top, f.rect.width, f.rect.height), name: f.name)
                ..value = f.value
                ..options = List<String>.from(f.options)
                ..group = f.group
                ..exportValue = f.exportValue
                ..fontSize = f.fontSize
                ..required = f.required
                ..checked = f.checked
                ..label = f.label
                ..labelSize = f.labelSize
                ..labelPosition = f.labelPosition
                ..tooltip = f.tooltip
                ..readOnly = f.readOnly
                ..maxLength = f.maxLength ?? 0
                ..comb = f.comb
                ..alignment = f.alignment
                ..multiSelect = f.multiSelect
                ..validationPattern = f.validation.pattern ?? ''
                ..minValue = f.validation.min?.toString() ?? ''
                ..maxValue = f.validation.max?.toString() ?? ''
                ..minLength = f.validation.minLength?.toString() ?? ''
                ..dateFormat = f.dateFormat.isEmpty ? 'dd/mm/yyyy' : f.dateFormat
                ..conditionRef = f.condition?.parent
                ..conditionField = f.condition == null
                    ? ''
                    : _nameForId(schema, f.condition!.parent)
                ..conditionOperator = f.condition?.operator ?? engine.ConditionOperator.equals
                ..conditionValue = f.condition?.value ?? ''
                ..calcFunction = f.calculation?.function ?? engine.CalculationFunction.sum
                ..calcRefs = List<engine.FieldRef>.from(
                    f.calculation?.fields ?? const <engine.FieldRef>[])
                ..calcFields = (f.calculation?.fields ?? const <engine.FieldRef>[])
                    .map((r) => _nameForId(schema, r))
                    .join(', '),
            );
      }
      // Restart auto-naming past anything the draft already used, so the next placed field
      // cannot collide with a restored one and trip the duplicate-name check on Create.
      _autoName = 1 + _highestAutoNameIn(schema);
    });
  }

  /// Largest trailing number in any restored field or group name, so `_autoName` resumes above
  /// it. Names are of the form `text_3` / `radio_group_7`.
  int _highestAutoNameIn(engine.FormSchema schema) {
    var highest = 0;
    final trailingNumber = RegExp(r'_(\d+)$');
    for (final f in schema.fields) {
      for (final candidate in [f.name, f.group]) {
        final match = trailingNumber.firstMatch(candidate);
        final value = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
        if (value > highest) highest = value;
      }
    }
    return highest;
  }

  Future<void> _open() async {
    try {
      _doc = await PdfDocument.openFile(widget.file.path);
      _totalPages = _doc!.pagesCount;
      await _loadPage(1);
      // Only after the first page is measured: restoring needs the page size to
      // be known so fractional rects land in the right place.
      await _restoreDraft();
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  Future<void> _loadPage(int pageNo) async {
    if (_doc == null) return;
    setState(() => _loadingPage = true);
    try {
      final page = await _doc!.getPage(pageNo);
      _pagePoints[pageNo] = Size(page.width, page.height);
      final img = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      if (!mounted) return;
      setState(() {
        _pageImage = img;
        _currentPage = pageNo;
        _selectedId = null;
        _loadingPage = false;
        _tc.value = Matrix4.identity();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  // ── Points ────────────────────────────────────────────────────────────────────
  // A field's rect is stored as a fraction of the page, and `AcroFormSpecMapper` turns it into
  // PDF points by multiplying by the page size. These do the same multiplication, so what the
  // author reads on screen is exactly what the backend receives — not an approximation of it.

  /// The current page's size in PDF points, or A4 if it has not been measured yet.
  Size get _currentPagePoints => _pagePoints[_currentPage] ?? const Size(595, 842);

  /// Smallest field size, expressed as a fraction of the current page.
  Size _minFraction() {
    const minPoints = 4.0;
    final p = _currentPagePoints;
    return Size(minPoints / p.width, minPoints / p.height);
  }

  /// [f]'s rectangle in PDF points — the numbers the backend will be given.
  Rect _rectInPoints(EditorField f) {
    final p = _currentPagePoints;
    return Rect.fromLTWH(
      f.rect.left * p.width,
      f.rect.top * p.height,
      f.rect.width * p.width,
      f.rect.height * p.height,
    );
  }

  /// Writes [f]'s rectangle from PDF points, clamped to the page and to the minimum size.
  void _setRectFromPoints(EditorField f, Rect points) {
    final p = _currentPagePoints;
    final min = _minFraction();
    final w = (points.width / p.width).clamp(min.width, 1.0);
    final h = (points.height / p.height).clamp(min.height, 1.0);
    final l = (points.left / p.width).clamp(0.0, 1 - w);
    final t = (points.top / p.height).clamp(0.0, 1 - h);
    setState(() => f.rect = Rect.fromLTWH(l, t, w, h));
  }

  /// Every other field on this page, by name, with its size in points — so a field can be made
  /// exactly the size of one already placed. Forms repeat the same box; measuring it once
  /// should be enough.
  Map<String, Size> _sizesOfFieldsOtherThan(EditorField f) {
    final result = <String, Size>{};
    for (final other in _fields) {
      if (other.id == f.id) continue;
      final r = _rectInPoints(other);
      result[other.name] = Size(r.width, r.height);
    }
    return result;
  }

  /// "142.0, 318.5 pt" — where the field's top-left corner sits on the page.
  String _positionLabel(EditorField f) {
    final r = _rectInPoints(f);
    return '${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)} pt';
  }

  /// "12.0 x 12.0 pt" — the size the backend will be given.
  String _sizeLabel(EditorField f) {
    final r = _rectInPoints(f);
    return '${r.width.toStringAsFixed(1)} x ${r.height.toStringAsFixed(1)} pt';
  }

  EditorField? get _selected {
    for (final f in _fields) {
      if (f.id == _selectedId) return f;
    }
    return null;
  }

  int get _totalFields => _pageFields.values.fold(0, (a, b) => a + b.length);

  /// Adds a field of [type] near the page centre, cascaded so successive fields
  /// don't stack exactly on top of one another, then selects it.
  /// Resolves a field name typed in the inspector to that field's id.
  ///
  /// Falls back to the name itself when nothing matches, so a rule typed before its target
  /// exists is preserved and reported as dangling rather than silently discarded.
  String _idForName(String name) {
    for (final pageFields in _pageFields.values) {
      for (final field in pageFields) {
        if (field.name == name) return field.id;
      }
    }
    return name;
  }

  /// The display name for a stored reference, for showing in the inspector.
  String _nameForId(engine.FormSchema schema, engine.FieldRef ref) {
    for (final field in schema.fields) {
      if (field.id == ref.id) return field.name;
    }
    return ref.name ?? ref.id; // deleted target: show what it used to be
  }

  /// Lists the fields on this page so one can be found by name rather than hunted for on the
  /// canvas, and reordered to set the tab order of the finished PDF.
  void _showFieldList() {
    showModalBottomSheet(
      context: context,
      // Without this the sheet runs under the status bar and the display cutout —
      // on a punch-hole phone the top of a tall sheet sits behind the camera.
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FieldListSheet(
        fields: List<EditorField>.from(_fields),
        selectedId: _selectedId,
        groupColor: _groupColor,
        groupLetter: _groupLetter,
        onSelect: (f) => setState(() => _selectedId = f.id),
        onReorder: (oldIndex, newIndex) {
          _pushUndo();
          setState(() {
            final moved = _fields.removeAt(oldIndex);
            _fields.insert(newIndex, moved);
          });
        },
      ),
    );
  }

  /// Records the current layout so the next change can be undone.
  void _pushUndo() {
    _undoStack.add(const engine.SchemaCodec().encode(_toSchema()));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _applySchema(const engine.SchemaCodec().decode(previous));
    setState(() => _selectedId = null);
  }

  /// Copies the selected field, offset slightly so the copy is visibly separate.
  void _duplicate(EditorField source) {
    _pushUndo();
    final copy = EditorField(
      type: source.type,
      rect: Rect.fromLTWH(
        (source.rect.left + 0.02).clamp(0.0, 1 - source.rect.width),
        (source.rect.top + 0.02).clamp(0.0, 1 - source.rect.height),
        source.rect.width,
        source.rect.height,
      ),
      name: '${source.type.wire}_${_autoName++}',
    )
      ..value = source.value
      ..options = List<String>.from(source.options)
      ..group = source.group
      ..fontSize = source.fontSize
      ..required = source.required
      ..checked = source.checked
      ..label = source.label
      ..labelSize = source.labelSize
      ..labelPosition = source.labelPosition
      ..tooltip = source.tooltip
      ..readOnly = source.readOnly
      ..maxLength = source.maxLength
      ..comb = source.comb
      ..alignment = source.alignment
      ..multiSelect = source.multiSelect
      ..validationPattern = source.validationPattern
      ..minValue = source.minValue
      ..maxValue = source.maxValue
      ..minLength = source.minLength
      ..dateFormat = source.dateFormat
      ..exportValue = source.exportValue
      ..conditionField = source.conditionField
      ..conditionOperator = source.conditionOperator
      ..conditionValue = source.conditionValue
      // The refs, not just the display strings. `_toSchema` serialises conditionRef/calcRefs;
      // copying only the typed names left the duplicate with a rule that pointed at nothing, so
      // its visibility condition and calculation quietly stopped working.
      ..conditionRef = source.conditionRef
      ..calcFunction = source.calcFunction
      ..calcRefs = List<engine.FieldRef>.from(source.calcRefs)
      ..calcFields = source.calcFields;
    setState(() {
      _fields.add(copy);
      _selectedId = copy.id;
    });
  }

  void _addField(FieldType type) {
    final size = type.defaultSizeOn(_pagePoints[_currentPage]);
    // Stack each new field under the previous one instead of nudging it by a fixed step.
    // The old step was 0.05 of the page while a Paragraph field is 0.12 tall, so placing a
    // few in a row buried them in each other and every one had to be dragged apart first.
    const gap = 0.012;
    double left = 0.12;
    double top = 0.18;
    if (_fields.isNotEmpty) {
      final last = _fields.last.rect;
      left = last.left;
      top = last.bottom + gap;
      if (top + size.height > 1.0) {
        // Off the bottom of the page — start a fresh column rather than stacking into the margin.
        top = 0.18;
        left = last.left + last.width + gap;
        if (left + size.width > 1.0) left = 0.12;
      }
    }
    _pushUndo();
    left = left.clamp(0.0, 1 - size.width);
    top = top.clamp(0.0, 1 - size.height);
    final n = _autoName++;
    final field = EditorField(
        type: type,
        rect: Rect.fromLTWH(left, top, size.width, size.height),
        name: '${type.wire}_$n');
    if (type.isGrouped) {
      // Its own group, and its own export value, so a second radio placed later is a
      // separate question until the author explicitly adds it to this group.
      field.group = '${type.wire}_group_$n';
      field.exportValue = 'option_1';
    }
    setState(() {
      _fields.add(field);
      _selectedId = field.id;
    });
  }

  /// Adds another option to [source]'s group, placed just below it.
  ///
  /// This is what makes a grouped question workable on a real document: the options of one
  /// question rarely sit in a neat column — on a bank form each sits beside its own printed
  /// label — so a new option is created linked but free, and the author drags it into place.
  void _addOptionToGroup(EditorField source) {
    _pushUndo();
    final existing = _fields.where((f) => f.group == source.group).length;
    final copy = EditorField(
      type: source.type,
      rect: Rect.fromLTWH(
        source.rect.left,
        (source.rect.bottom + 0.012).clamp(0.0, 1 - source.rect.height),
        source.rect.width,
        source.rect.height,
      ),
      name: '${source.group}_${existing + 1}',
    )
      ..group = source.group
      ..exportValue = 'option_${existing + 1}'
      // A new option starts unlabelled rather than inheriting the sibling's caption, which
      // would put "Savings" beside every circle in the group.
      ..labelSize = source.labelSize
      ..labelPosition = source.labelPosition
      ..required = source.required
      ..tooltip = source.tooltip;
    setState(() {
      _fields.add(copy);
      _selectedId = copy.id;
    });
  }

  /// Adds a group of linked [type] (radio or checkbox) options in a neat column
  /// from a list of labels. Radios share one group name; checkboxes share a base.
  void _addGroup(FieldType type, List<String> labels) {
    _pushUndo();
    final size = type.defaultSizeOn(_pagePoints[_currentPage]);
    final groupName = '${type.wire}_group_${_autoName++}';
    setState(() {
      for (int i = 0; i < labels.length; i++) {
        final top = (0.2 + i * (size.height + 0.03)).clamp(0.0, 1 - size.height);
        final f = EditorField(type: type, rect: Rect.fromLTWH(0.12, top, size.width, size.height), name: '${groupName}_${i + 1}');
        if (type.isGrouped) {
          f.group = groupName;
          f.exportValue = labels[i];
          // What the author typed is the caption too — that is what they meant by it.
          f.label = labels[i];
        }
        _fields.add(f);
        if (i == labels.length - 1) _selectedId = f.id;
      }
    });
  }

  Future<void> _promptGroup(FieldType type) async {
    // Localized: these are used verbatim as the group's export values, so leaving them English
    // put English option values inside a Hindi author's PDF.
    final controller = TextEditingController(
        text: [1, 2, 3].map(L10n.current.optionLabelDefault).join(', '));
    final labels = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).formGroupTitle(type.localizedLabel(ctx))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L10n.of(context).optionLabelsHint, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(context).cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
            child: Text(L10n.of(context).add),
          ),
        ],
      ),
    );
    if (labels != null && labels.isNotEmpty) _addGroup(type, labels);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // The title still read "Form Edit…" with a full-size Create button beside two icons.
        // Reclaiming the default 16px gap and tightening the button is what makes it fit.
        titleSpacing: 0,
        title: Text(ToolStrings.name(context, 'fill-form'), overflow: TextOverflow.ellipsis),
        actions: [
          // Only two icons besides Create. Undo, the field list, duplicate and fit all moved
          // into the overflow: with them inline the title had no room and truncated to "For…",
          // and adding the preview toggle would have made it worse.
          IconButton(
            icon: Icon(_previewMode ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            tooltip: _previewMode
                ? L10n.of(context).formShowEditingAids
                : L10n.of(context).formPreviewOutput,
            isSelected: _previewMode,
            onPressed: () => setState(() => _previewMode = !_previewMode),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'undo':
                  _undo();
                case 'fields':
                  _showFieldList();
                case 'duplicate':
                  final selected = _fields.where((f) => f.id == _selectedId).firstOrNull;
                  if (selected != null) _duplicate(selected);
                case 'fit':
                  setState(() => _tc.value = Matrix4.identity());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'undo',
                enabled: _undoStack.isNotEmpty,
                child: Row(children: [
                  const Icon(Icons.undo, size: 20),
                  const SizedBox(width: 12),
                  Text(L10n.of(context).undoAction),
                ]),
              ),
              PopupMenuItem(
                value: 'fields',
                child: Row(children: [
                  const Icon(Icons.list_alt_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(L10n.of(context).a11yOpenFieldList),
                ]),
              ),
              PopupMenuItem(
                value: 'duplicate',
                enabled: _selectedId != null,
                child: Row(children: [
                  const Icon(Icons.copy_all_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(L10n.of(context).duplicateField),
                ]),
              ),
              PopupMenuItem(
                value: 'fit',
                child: Row(children: [
                  const Icon(Icons.fit_screen_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(L10n.of(context).fitToScreen),
                ]),
              ),
            ],
          ),
          // Primary action — enabled once there's at least one field and no
          // submit in flight.
          BlocBuilder<PdfBloc, PdfState>(
            buildWhen: (p, c) => p.httpStates[HttpStates.createForm] != c.httpStates[HttpStates.createForm],
            builder: (context, state) {
              final busy = state.httpStates[HttpStates.createForm]?.loading == true;
              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 8, 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: (_totalFields > 0 && !busy) ? _onSave : null,
                  child: Text(L10n.of(context).create),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.createForm] != c.httpStates[HttpStates.createForm],
        listenWhen: (p, c) => p.httpStates[HttpStates.createForm] != c.httpStates[HttpStates.createForm],
        listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.createForm], successMessage: L10n.current.formCreated),
        builder: (context, state) {
          return Stack(children: [
            Column(children: [
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvasArea(theme),
              ),
              _buildPalette(theme),
            ]),
            processingOverlay(state.httpStates[HttpStates.createForm],
                label: L10n.of(context).creatingForm),
          ]);
        },
      ),
    );
  }

  // ── Canvas ──────────────────────────────────────────────────────────────────

  Widget _buildCanvasArea(ThemeData theme) {
    return Stack(children: [
      Positioned.fill(child: _buildCanvas(theme)),
      // Floating page navigator (only when multi-page).
      if (_totalPages > 1)
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(child: _pagePill(theme)),
        ),
      // Precision controls for the selected field. A drag moves in whole logical pixels, and at
      // fit scale one pixel is roughly 1.5pt on A4 — so a field simply cannot be landed on a
      // printed box by finger alone. These move it a point at a time.
      if (_selected != null && !_previewMode)
        Positioned(right: 8, bottom: 12, child: _nudgePad(theme)),
      // Zoom, so a 12pt box is big enough to aim at.
      Positioned(left: 8, bottom: 12, child: _zoomPad(theme)),
      // Empty-state hint for the current page.
      if (_fields.isEmpty)
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.surface),
              ),
              child: Text(L10n.of(context).tapFieldToPlace,
                  style: TextStyle(fontSize: 12.5, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
    ]);
  }

  Widget _pagePill(ThemeData theme) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.surface),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
          ),
          Text('$_currentPage / $_totalPages', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _currentPage < _totalPages ? () => _loadPage(_currentPage + 1) : null,
          ),
        ]),
      ),
    );
  }

  /// One-point nudge in each direction for the selected field.
  Widget _nudgePad(ThemeData theme) {
    final l = L10n.of(context);
    Widget arrow(IconData icon, Offset deltaPoints, String label) => Semantics(
          button: true,
          label: label,
          child: IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(icon),
            onPressed: () => _nudge(deltaPoints),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        arrow(Icons.keyboard_arrow_up, const Offset(0, -1), l.nudgeUp),
        Row(mainAxisSize: MainAxisSize.min, children: [
          arrow(Icons.keyboard_arrow_left, const Offset(-1, 0), l.nudgeLeft),
          arrow(Icons.keyboard_arrow_right, const Offset(1, 0), l.nudgeRight),
        ]),
        arrow(Icons.keyboard_arrow_down, const Offset(0, 1), l.nudgeDown),
      ]),
    );
  }

  /// Moves the selected field by [deltaPoints] PDF points and shows the new position.
  void _nudge(Offset deltaPoints) {
    final f = _selected;
    if (f == null) return;
    _pushUndo();
    final r = _rectInPoints(f);
    _setRectFromPoints(f, r.translate(deltaPoints.dx, deltaPoints.dy));
    setState(() => _dragReadout = _positionLabel(f));
  }

  /// Zoom in/out with a readout, next to the canvas rather than buried in the overflow menu.
  Widget _zoomPad(ThemeData theme) {
    return AnimatedBuilder(
      animation: _tc,
      builder: (context, _) {
        final scale = _tc.value.getMaxScaleOnAxis();
        void zoomTo(double target) {
          final clamped = target.clamp(1.0, _maxZoom);
          setState(() =>
              _tc.value = Matrix4.identity()..scaleByDouble(clamped, clamped, 1, 1));
        }

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.surface),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              tooltip: L10n.of(context).zoomOut,
              icon: const Icon(Icons.remove),
              onPressed: scale > 1.01 ? () => zoomTo(scale / 1.5) : null,
            ),
            ExcludeSemantics(
              child: Text('${(scale * 100).round()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              tooltip: L10n.of(context).zoomIn,
              icon: const Icon(Icons.add),
              onPressed: scale < _maxZoom - 0.01 ? () => zoomTo(scale * 1.5) : null,
            ),
          ]),
        );
      },
    );
  }

  Widget _buildCanvas(ThemeData theme) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final pageSize = _pagePoints[_currentPage] ?? const Size(595, 842);
      final pageAspect = pageSize.width / pageSize.height;
      final areaAspect = constraints.maxWidth / constraints.maxHeight;
      double dispW, dispH;
      if (pageAspect > areaAspect) {
        dispW = constraints.maxWidth;
        dispH = dispW / pageAspect;
      } else {
        dispH = constraints.maxHeight;
        dispW = dispH * pageAspect;
      }

      return Center(
        child: SizedBox(
          width: dispW,
          height: dispH,
          // Clip.none so edge handles of a selected field aren't cut off.
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
                ),
                child: InteractiveViewer(
                  transformationController: _tc,
                  minScale: 1,
                  // 5x was not enough to see a 12pt checkbox, let alone place one: at fit scale
                  // on a phone a point is well under a logical pixel.
                  maxScale: _maxZoom,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _selectAt(d.localPosition, dispW, dispH),
                    child: Stack(clipBehavior: Clip.none, children: [
                      if (_pageImage != null)
                        Positioned.fill(child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill)),
                      ..._fields.map((f) => _fieldVisual(f, dispW, dispH, theme)),
                    ]),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _tc,
              builder: (context, _) {
                final f = _selected;
                if (f == null) return const SizedBox.shrink();
                return _buildHandles(f, dispW, dispH, theme);
              },
            ),
          ]),
        ),
      );
    });
  }

  void _selectAt(Offset local, double dispW, double dispH) {
    final p = Offset(local.dx / dispW, local.dy / dispH);
    for (final f in _fields.reversed) {
      if (f.rect.contains(p)) {
        setState(() => _selectedId = f.id);
        return;
      }
    }
    setState(() => _selectedId = null);
  }

  /// Distinct colours for grouped fields.
  ///
  /// Chosen to stay legible over a white page and to remain distinguishable for the common
  /// forms of colour blindness (blue/orange/purple/teal carry different lightness as well as
  /// hue). Colour alone is never the only cue — every grouped field also carries the group's
  /// letter, so the grouping survives a greyscale print or a colour-blind reader.
  static const List<Color> _groupPalette = [
    Color(0xFF1565C0), // blue
    Color(0xFFEF6C00), // orange
    Color(0xFF6A1B9A), // purple
    Color(0xFF00838F), // teal
    Color(0xFFC62828), // red
    Color(0xFF2E7D32), // green
    Color(0xFF4E342E), // brown
    Color(0xFFAD1457), // pink
  ];

  /// Groups on the current page, in the order they first appear, so a group's colour and
  /// letter stay put while the author works rather than shuffling on every edit.
  List<String> get _groupOrder {
    final seen = <String>[];
    for (final f in _fields) {
      if (f.type.isGrouped && f.group.isNotEmpty && !seen.contains(f.group)) {
        seen.add(f.group);
      }
    }
    return seen;
  }

  Color _groupColor(String group) {
    final index = _groupOrder.indexOf(group);
    return index < 0 ? Colors.grey : _groupPalette[index % _groupPalette.length];
  }

  /// A, B, C… for the group. Wraps to A1, B1… beyond 26 groups, which no real form reaches
  /// but which keeps the label unambiguous if one does.
  String _groupLetter(String group) {
    final index = _groupOrder.indexOf(group);
    if (index < 0) return '?';
    final letter = String.fromCharCode(65 + (index % 26));
    final cycle = index ~/ 26;
    return cycle == 0 ? letter : '$letter$cycle';
  }

  Widget _fieldVisual(EditorField f, double dispW, double dispH, ThemeData theme) {
    final r = Rect.fromLTWH(f.rect.left * dispW, f.rect.top * dispH, f.rect.width * dispW, f.rect.height * dispH);
    final isSel = f.id == _selectedId;
    final grouped = f.type.isGrouped && f.group.isNotEmpty;

    // Grouped fields take their group's colour so membership is visible at a glance; a radio
    // is far too small to carry a readable name, which is why the group used to be invisible
    // unless you opened each field in turn.
    final primary = grouped ? _groupColor(f.group) : theme.colorScheme.primary;

    // Selecting one option lights up the rest of its group, which answers "what else is in
    // here?" without the author hunting for matching colours.
    final selected = _fields.where((x) => x.id == _selectedId).firstOrNull;
    final isSibling = !isSel &&
        grouped &&
        selected != null &&
        selected.type.isGrouped &&
        selected.group == f.group;

    // Display pixels per PDF point for this page — the scale the painter needs so a 1pt
    // border is one point wide on screen rather than one logical pixel.
    final points = _pagePoints[_currentPage];
    final pxPerPoint = points == null ? 1.0 : dispW / points.width;

    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        child: Semantics(
          label: grouped
              ? L10n.of(context).a11yFieldInGroup(
                  f.type.localizedLabel(context), f.name, _groupLetter(f.group))
              : L10n.of(context).a11yField(f.type.localizedLabel(context), f.name),
          selected: isSel,
          // Clip.none so a caption drawn beside or above the field is not cut off at the
          // field's own bounds — on a 12pt checkbox that would clip it away entirely.
          child: Stack(clipBehavior: Clip.none, children: [
            // 1. The field as the PDF will actually draw it. Nothing decorative here — this
            //    layer is what the author is really placing.
            Positioned.fill(
              child: CustomPaint(
                painter: FieldAppearancePainter(
                  type: f.type,
                  checked: f.checked,
                  pxPerPoint: pxPerPoint,
                ),
              ),
            ),
            // 1b. The caption, drawn where the backend draws it: to the right of a toggle,
            //     vertically centred on it; above anything else. Part of the output, so it
            //     stays visible in Preview mode.
            if (f.label.isNotEmpty) _labelVisual(f, r, pxPerPoint, theme),
            // 2. Editing chrome on top. It exists to make the layout workable — which field is
            //    this, what group is it in — and is hidden by the Preview toggle so the author
            //    can see the unadorned output at any moment.
            if (!_previewMode) ...[
              // On anything roomy, a wash plus a border — the true appearance stays readable
              // through it. On a 12pt toggle the same treatment covered the field completely:
              // a blue rectangle where a black circle should be, which is precisely what the
              // WYSIWYG work exists to avoid. There the marker goes *outside* instead.
              if (f.type.isToggle)
                Positioned(
                  left: -3,
                  top: -3,
                  right: -3,
                  bottom: -3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSel || isSibling
                            ? primary
                            : primary.withValues(alpha: 0.5),
                        width: isSel ? 1.6 : 1,
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          primary.withValues(alpha: isSel ? 0.12 : (isSibling ? 0.10 : 0.05)),
                      border: Border.all(
                        color: isSel || isSibling ? primary : primary.withValues(alpha: 0.35),
                        width: isSel ? 1.8 : (isSibling ? 1.6 : 0.8),
                      ),
                    ),
                  ),
                ),
              // Type badge, plus the field's own name once the box is big enough to hold it.
              // A form of any size is unreadable from icons alone — every text field looks
              // identical, so finding "account_number" meant opening each one in turn.
              // Suppressed on a toggle, which is far too small to carry a badge without
              // burying the very glyph the author is trying to line up.
              if (!f.type.isToggle)
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isSel ? 0.9 : 0.5),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.surface),
                          bottomRight: Radius.circular(AppRadius.surface)),
                    ),
                    child: Icon(f.type.icon, size: 10, color: Colors.white),
                  ),
                ),
              // The group's letter. This is the cue that works where the name label cannot: a
              // radio is far too narrow for text, so without it the grouping is invisible.
              //
              // On a toggle it is placed *outside* the field, to its left. A 12pt checkbox is
              // about the size of the badge itself, so drawing it in the corner covered the very
              // glyph the author is trying to line up on the page.
              if (grouped && f.type.isToggle)
                Positioned(
                  right: r.width + 3,
                  top: (r.height - 13) / 2,
                  child: _groupBadge(f, primary, isSel || isSibling),
                ),
              if (grouped && !f.type.isToggle)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isSel || isSibling ? 1 : 0.7),
                      borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(AppRadius.surface),
                          bottomLeft: Radius.circular(AppRadius.surface)),
                    ),
                    child: Text(
                      _groupLetter(f.group),
                      style: const TextStyle(
                          fontSize: 8.5,
                          height: 1.2,
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              // Small fields (a 12pt checkbox) have no room for a label, and a radio's useful
              // identity is its group rather than its own name.
              if (r.width > 70 && r.height > 18)
                Padding(
                  padding: EdgeInsets.only(
                      left: f.type.isToggle ? 3 : 16, right: grouped ? 16 : 3, top: 1),
                  child: Text(
                    f.type.isGrouped && f.group.isNotEmpty ? f.group : f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9,
                        height: 1.1,
                        color: primary.withValues(alpha: isSel ? 1 : 0.75),
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  /// The group's letter on a coloured chip — A, B, C…
  ///
  /// Colour alone is never the only cue: the letter survives a greyscale print and a colour-blind
  /// reader, which is why grouping is shown this way rather than by tint.
  Widget _groupBadge(EditorField f, Color primary, bool bright) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: bright ? 1 : 0.7),
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        child: Text(
          _groupLetter(f.group),
          style: const TextStyle(
              fontSize: 8.5, height: 1.2, color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );

  /// The field's caption, positioned the way the backend positions it.
  ///
  /// The side is the author's choice; the geometry on each side matches the backend exactly.
  Widget _labelVisual(EditorField f, Rect r, double pxPerPoint, ThemeData theme) {
    final sizePt = f.labelSize > 0 ? f.labelSize : _defaultLabelPoints;
    final fontPx = sizePt * pxPerPoint;
    final gap = _labelGapPoints * pxPerPoint;
    final text = Text(
      f.label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: TextStyle(
        fontSize: fontPx,
        height: 1.0,
        color: Colors.black,
        fontWeight: FontWeight.w400,
      ),
    );

    final child = ExcludeSemantics(child: text);
    // Positioned outside the field's own bounds — a 12pt square cannot contain a caption — and
    // laid out exactly as the backend lays it out, so the preview does not lie about where the
    // text will end up.
    return switch (f.labelPosition) {
      engine.LabelPosition.right =>
        Positioned(left: r.width + gap, top: (r.height - fontPx) / 2, child: child),
      engine.LabelPosition.left =>
        Positioned(right: r.width + gap, top: (r.height - fontPx) / 2, child: child),
      engine.LabelPosition.above => Positioned(left: 0, top: -(fontPx + gap), child: child),
      engine.LabelPosition.below => Positioned(left: 0, top: r.height + gap, child: child),
    };
  }

  Widget _buildHandles(EditorField f, double dispW, double dispH, ThemeData theme) {
    final scale = _tc.value.getMaxScaleOnAxis();
    final sceneTL = Offset(f.rect.left * dispW, f.rect.top * dispH);
    final screenTL = MatrixUtils.transformPoint(_tc.value, sceneTL);
    final w = f.rect.width * dispW * scale;
    final h = f.rect.height * dispH * scale;
    final primary = theme.colorScheme.primary;

    void move(Offset screenDelta) {
      final dxFrac = (screenDelta.dx / scale) / dispW;
      final dyFrac = (screenDelta.dy / scale) / dispH;
      setState(() {
        final nl = (f.rect.left + dxFrac).clamp(0.0, 1 - f.rect.width);
        final nt = (f.rect.top + dyFrac).clamp(0.0, 1 - f.rect.height);
        f.rect = Rect.fromLTWH(nl, nt, f.rect.width, f.rect.height);
        _dragReadout = _positionLabel(f);
      });
    }

    void resize(Offset screenDelta) {
      final dwFrac = (screenDelta.dx / scale) / dispW;
      final dhFrac = (screenDelta.dy / scale) / dispH;
      setState(() {
        // The floor is four points, not a fraction of the page. A flat 0.02 floor meant a
        // minimum of 11.9pt wide and 16.8pt tall on A4, so a 12pt checkbox — the size printed
        // on the forms these get placed on — could not be reached at all.
        final minW = _minFraction().width;
        final minH = _minFraction().height;
        var nw = (f.rect.width + dwFrac).clamp(minW, 1 - f.rect.left);
        var nh = (f.rect.height + dhFrac).clamp(minH, 1 - f.rect.top);
        if (f.type.lockAspect) {
          // Both axes follow whichever the finger moved further, in points rather than in
          // fractions, so the field stays physically square instead of square-in-fractions.
          final points = _pagePoints[_currentPage] ?? const Size(595, 842);
          final sidePt = (dwFrac.abs() * points.width >= dhFrac.abs() * points.height)
              ? nw * points.width
              : nh * points.height;
          nw = (sidePt / points.width).clamp(minW, 1 - f.rect.left);
          nh = (sidePt / points.height).clamp(minH, 1 - f.rect.top);
          // The clamps can pull the axes apart at the page edge; take the smaller side so the
          // field stays square and inside the page.
          final side = math.min(nw * points.width, nh * points.height);
          nw = side / points.width;
          nh = side / points.height;
        }
        f.rect = Rect.fromLTWH(f.rect.left, f.rect.top, nw, nh);
        _dragReadout = _sizeLabel(f);
      });
    }

    Widget circle(IconData icon, Color color, VoidCallback? onTap,
        {void Function(Offset)? onDrag, required String semanticLabel}) {
      return Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onPanStart: onDrag == null ? null : (_) => _pushUndo(),
          onPanUpdate: onDrag == null ? null : (d) => onDrag(d.delta),
          onPanEnd: onDrag == null ? null : (_) => setState(() => _dragReadout = null),
          // The visible dot stays 26px so it does not swamp a small field, but the *touch*
          // target is padded out to the 48dp minimum. At 26px these handles were below the
          // accessibility guideline and genuinely fiddly to hit on a phone.
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2)),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
          ),
        ),
      );
    }

    // Handles are centred on the field's corners. `circle` is a 48dp touch target with a 26px
    // dot in the middle of it, so half of 48 is what centres the dot — not half of 26. Using 13
    // shifted every handle 11px right and down, which is why a radio sat in the top-left corner
    // of the square the four handles made instead of in the middle of it.
    const handleBox = 48.0;
    const handleDot = 26.0;
    const half = handleBox / 2;

    // On a text box the handles can sit on the corners. On a 12pt checkbox four 26px dots would
    // bury the thing being edited and overlap each other, so they are pushed out per axis until
    // they clear the field and leave a gap between neighbours.
    // 22, not 8: a 12pt toggle is about 22 logical pixels wide and a handle dot is 26, so the
    // four handles are each larger than the field they surround. With a small gap they close
    // into a solid cluster and the radio disappears underneath its own controls — which is
    // exactly what it looked like on device.
    const clearance = 22.0;
    final outwardX = math.max(0.0, (handleDot + clearance - w) / 2);
    final outwardY = math.max(0.0, (handleDot + clearance - h) / 2);

    return Stack(clipBehavior: Clip.none, children: [
      // Move body.
      Positioned(
        left: screenTL.dx,
        top: screenTL.dy,
        width: w,
        height: h,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _pushUndo(),
          onPanUpdate: (d) => move(d.delta),
          onPanEnd: (_) => setState(() => _dragReadout = null),
          onTap: () => _showProperties(f),
          child: const SizedBox.expand(),
        ),
      ),
      // Edit (top-left).
      Positioned(
          left: screenTL.dx - half - outwardX,
          top: screenTL.dy - half - outwardY,
          child: circle(Icons.edit, primary, () => _showProperties(f),
              semanticLabel: L10n.of(context).a11yEditField)),
      // Delete (top-right).
      Positioned(
        left: screenTL.dx + w - half + outwardX,
        top: screenTL.dy - half - outwardY,
        child: circle(Icons.close, Colors.red, semanticLabel: L10n.of(context).a11yDeleteField, () {
          _pushUndo();
          setState(() {
            _fields.remove(f);
            _selectedId = null;
          });
        }),
      ),
      // Add-another-option (bottom-left), for grouped fields only.
      //
      // Adding a second radio previously meant opening the properties sheet and scrolling past
      // Appearance and Rules to find the button — three steps for the single most common thing
      // you do with a radio. On a bank form each option sits beside its own printed label, so
      // the new option appears linked but free and is dragged into place.
      if (f.type.isGrouped && f.group.isNotEmpty)
        Positioned(
          left: screenTL.dx - half - outwardX,
          top: screenTL.dy + h - half + outwardY,
          child: circle(Icons.add, _groupColor(f.group), () => _addOptionToGroup(f),
              semanticLabel: L10n.of(context).a11yAddOption),
        ),
      // Resize (bottom-right).
      Positioned(
          left: screenTL.dx + w - half + outwardX,
          top: screenTL.dy + h - half + outwardY,
          child: circle(Icons.open_in_full, primary, null,
              onDrag: resize, semanticLabel: L10n.of(context).a11yResizeField)),
      // Live size/position readout. Sits above the field, or below it when the field is near
      // the top of the page, so it never leaves the canvas.
      if (_dragReadout != null)
        Positioned(
          left: screenTL.dx,
          top: screenTL.dy > 40 ? screenTL.dy - 30 : screenTL.dy + h + 8,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppRadius.surface),
              ),
              child: Text(
                _dragReadout!,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
    ]);
  }

  // ── Properties (modal sheet, rebuilt per open) ───────────────────────────────

  void _showProperties(EditorField f) {
    showModalBottomSheet(
      context: context,
      // Without this the sheet runs under the status bar and the display cutout —
      // on a punch-hole phone the top of a tall sheet sits behind the camera.
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.surface))),
      // StatefulBuilder so typing a new size redraws the sheet's own boxes as well as the
      // canvas; without it the numbers would only catch up when the sheet was reopened.
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => FieldInspector(
          field: f,
          rectInPoints: _rectInPoints(f),
          onRectChanged: (points) {
            _pushUndo();
            _setRectFromPoints(f, points);
            setSheetState(() {});
          },
          sizesOfOtherFields: _sizesOfFieldsOtherThan(f),
          resolve: (name) => engine.FieldRef(_idForName(name), name),
          onAddOption: _addOptionToGroup,
          optionsInGroup: (g) =>
              _pageFields.values.expand((l) => l).where((x) => x.group == g).length,
          groupLetter: _groupLetter,
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() {}); // refresh badges/state after edits
    });
  }

  /// The placed layout as an engine schema.
  ///
  /// This is the editor's output and the thing worth persisting: page-relative
  /// coordinates, so the same layout survives any zoom or render size, and no
  /// knowledge of the backend's wire format.
  engine.FormSchema _toSchema() {
    final fields = <engine.FormFieldModel>[];
    _pageFields.forEach((page, pageFields) {
      for (final f in pageFields) {
        fields.add(engine.FormFieldModel(
          id: f.id,
          typeId: f.type.wire,
          page: page,
          rect: engine.FractionalRect(f.rect.left, f.rect.top, f.rect.width, f.rect.height),
          name: f.name,
          value: f.value,
          options: List<String>.from(f.options),
          group: f.group,
          exportValue: f.exportValue,
          fontSize: f.fontSize,
          required: f.required,
          checked: f.checked,
          label: f.label,
          labelSize: f.labelSize,
          labelPosition: f.labelPosition,
          tooltip: f.tooltip,
          readOnly: f.readOnly,
          maxLength: f.maxLength > 0 ? f.maxLength : null,
          comb: f.comb,
          alignment: f.alignment,
          multiSelect: f.multiSelect,
          format: formFieldTypes.lookup(f.type.wire)?.defaultFormat ??
              engine.TextFormat.none,
          dateFormat: f.type == FieldType.date ? f.dateFormat : '',
          validation: engine.FieldValidation(
            pattern: f.validationPattern.isEmpty ? null : f.validationPattern,
            // Bounds the runtime has always enforced; until now nothing in the UI could set them.
            min: num.tryParse(f.minValue.trim()),
            max: num.tryParse(f.maxValue.trim()),
            minLength: int.tryParse(f.minLength.trim()),
          ),
          // The inspector takes field *names* because that is what the author sees on the
          // canvas, but rules are stored by id so a later rename cannot silently rewire them.
          // An unresolved name is kept verbatim and surfaces as a dangling reference rather
          // than being dropped.
          // References were resolved to ids when they were typed; a rename since then
          // changes the display name only, never the link.
          condition: f.conditionRef == null
              ? null
              : engine.VisibilityCondition(
                  parent: f.conditionRef!,
                  operator: f.conditionOperator,
                  value: f.conditionValue),
          calculation: f.calcRefs.isEmpty
              ? null
              : engine.Calculation(function: f.calcFunction, fields: f.calcRefs),
        ));
      }
    });
    return engine.FormSchema(
      fields: fields,
      pageSizes: {
        for (final e in _pagePoints.entries)
          e.key: engine.PageSizePoints(e.value.width, e.value.height),
      },
    );
  }

  /// Shows anything structurally wrong with the form before it is built.
  ///
  /// The engine has detected these all along; nothing surfaced them, so a form with two
  /// fields sharing a name silently produced a PDF where one value overwrote the other.
  /// Reported rather than blocked: the author may be mid-edit and know better.
  Future<bool> _confirmIssues() async {
    final issues = engine.FormRuntime(_toSchema()).integrityIssues();
    if (issues.isEmpty) return true;

    final names = {for (final f in _pageFields.values.expand((l) => l)) f.id: f.name};
    String describe(engine.SchemaIssue i) {
      final field = names[i.fieldId] ?? i.fieldId;
      return switch (i.problem) {
        engine.SchemaProblem.duplicateName => L10n.current.issueDuplicateName(i.target),
        engine.SchemaProblem.selfReference => L10n.current.issueSelfReference(field),
        engine.SchemaProblem.danglingCondition ||
        engine.SchemaProblem.danglingCalculation =>
          L10n.current.issueDangling(field),
      };
    }

    // The same problem on several fields reads as one problem to the author.
    final lines = issues.map(describe).toSet().toList();
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).formIssuesTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• '),
                  Expanded(child: Text(line)),
                ]),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.of(ctx).goBackAndFix)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(ctx).createAnyway)),
        ],
      ),
    );
    return proceed == true;
  }

  Future<void> _onSave() async {
    if (!await _confirmIssues()) return;
    if (!mounted) return;
    // The mapping to the backend's request lives in the engine, where a golden
    // test pins the exact JSON the running server parses.
    final specs = engine.AcroFormSpecMapper(formFieldTypes).toSpecs(_toSchema());

    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => CreateFormEvent(
          createForm: CreateForm(
            outFileName: 'fillable_${widget.file.path.split('/').last.replaceAll('.pdf', '')}',
            fields: specs,
            file: file,
          ),
          cancelToken: cancelToken,
        ));
  }

  // ── Bottom palette ───────────────────────────────────────────────────────────

  Widget _buildPalette(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final t in FieldType.values) _paletteItem(theme, t),
              _paletteGroupItem(theme, FieldType.radio, L10n.of(context).radioGroup, Icons.radio_button_checked),
              _paletteGroupItem(theme, FieldType.checkbox, L10n.of(context).checkGroup, Icons.checklist),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paletteGroupItem(ThemeData theme, FieldType t, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.surface),
        onTap: () => _promptGroup(t),
        child: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.surface),
            border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.secondary),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paletteItem(ThemeData theme, FieldType t) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.surface),
        onTap: () => _addField(t),
        child: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.surface),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t.icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(t.localizedLabel(context), style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Keep the layout for next time. Fire-and-forget: dispose cannot await, and
    // a failed draft write must never hold up closing the screen.
    final store = _drafts;
    if (store != null) unawaited(store.save(widget.file.path, _toSchema()));
    _tc.dispose();
    _doc?.close();
    super.dispose();
  }
}
