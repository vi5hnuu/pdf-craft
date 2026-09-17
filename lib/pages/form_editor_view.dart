import 'dart:io';
import 'package:pdf_craft/pages/form-editor/editor_field.dart';
import 'package:pdf_craft/pages/form-editor/field_inspector.dart';
import 'package:pdf_craft/pages/form-editor/field_list_sheet.dart';
import 'package:pdf_craft/pages/form-editor/form_field_type.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/create_form.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/loading_overlay.dart';
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

class _FormEditorViewState extends State<FormEditorView> {
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

  final TransformationController _tc = TransformationController();
  CancelToken? _cancelToken;
  FormDraftStore? _drafts;

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
    });
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
      ..tooltip = source.tooltip
      ..readOnly = source.readOnly
      ..maxLength = source.maxLength
      ..comb = source.comb
      ..alignment = source.alignment
      ..multiSelect = source.multiSelect
      ..validationPattern = source.validationPattern
      ..conditionField = source.conditionField
      ..conditionOperator = source.conditionOperator
      ..conditionValue = source.conditionValue
      ..calcFunction = source.calcFunction
      ..calcFields = source.calcFields;
    setState(() {
      _fields.add(copy);
      _selectedId = copy.id;
    });
  }

  void _addField(FieldType type) {
    final size = type.defaultSize;
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
    final size = type.defaultSize;
    final groupName = '${type.wire}_group_${_autoName++}';
    setState(() {
      for (int i = 0; i < labels.length; i++) {
        final top = (0.2 + i * (size.height + 0.03)).clamp(0.0, 1 - size.height);
        final f = EditorField(type: type, rect: Rect.fromLTWH(0.12, top, size.width, size.height), name: '${groupName}_${i + 1}');
        if (type.isGrouped) {
          f.group = groupName;
          f.exportValue = labels[i];
        }
        _fields.add(f);
        if (i == labels.length - 1) _selectedId = f.id;
      }
    });
  }

  Future<void> _promptGroup(FieldType type) async {
    final controller = TextEditingController(text: 'Option 1, Option 2, Option 3');
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
        title: Text(ToolStrings.name(context, 'fill-form')),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: L10n.of(context).undoAction,
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: L10n.of(context).a11yOpenFieldList,
            onPressed: _showFieldList,
          ),
          // Duplicate and fit-to-screen moved into an overflow menu: with five actions plus the
          // Create button the title had no room left and truncated to "For…".
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'duplicate') {
                final selected = _fields.where((f) => f.id == _selectedId).firstOrNull;
                if (selected != null) _duplicate(selected);
              } else if (v == 'fit') {
                setState(() => _tc.value = Matrix4.identity());
              }
            },
            itemBuilder: (context) => [
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: FilledButton(
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
        listener: (context, state) {
          final s = state.httpStates[HttpStates.createForm];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: L10n.current.formCreated, color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path},
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
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
            LoadingOverlay(
              httpState: state.httpStates[HttpStates.createForm],
              label: L10n.of(context).creatingForm,
              onCancel: () => _cancelToken?.cancel('cancelled-by-user'),
            ),
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
                  maxScale: 5,
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
          child: Container(
          decoration: BoxDecoration(
            color: primary.withValues(alpha: isSel ? 0.12 : (isSibling ? 0.10 : 0.06)),
            border: Border.all(
              color: isSel || isSibling ? primary : primary.withValues(alpha: 0.45),
              width: isSel ? 1.8 : (isSibling ? 1.6 : 1),
            ),
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          // Type badge, plus the field's own name once the box is big enough to hold it.
          // A form of any size is unreadable from icons alone — every text field looks
          // identical, so finding "account_number" meant opening each one in turn.
          child: Stack(children: [
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
            // The group's letter, in the opposite corner to the type badge. This is the cue
            // that works where the name label cannot: a radio is about 50x25px on screen, far
            // too narrow for text, so without this its group was invisible on the canvas.
            if (grouped)
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
            // Small fields (a checkbox is ~30x25pt) have no room for a label, and a radio's
            // useful identity is its group rather than its own name.
            if (r.width > 70 && r.height > 18)
              Padding(
                padding: EdgeInsets.only(left: 16, right: grouped ? 16 : 3, top: 1),
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
          ]),
        ),
        ),
      ),
    );
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
      });
    }

    void resize(Offset screenDelta) {
      final dwFrac = (screenDelta.dx / scale) / dispW;
      final dhFrac = (screenDelta.dy / scale) / dispH;
      setState(() {
        final nw = (f.rect.width + dwFrac).clamp(0.02, 1 - f.rect.left);
        final nh = (f.rect.height + dhFrac).clamp(0.02, 1 - f.rect.top);
        f.rect = Rect.fromLTWH(f.rect.left, f.rect.top, nw, nh);
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
          onPanUpdate: onDrag == null ? null : (d) => onDrag(d.delta),
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

    // The three 26px handles sit on the corners, which is fine on a text box but hides a
    // checkbox entirely — the field it is meant to be editing disappears under its own
    // controls. On a small field they move fully outside the bounds instead.
    final outward = (w < 90 || h < 64) ? 14.0 : 0.0;

    return Stack(clipBehavior: Clip.none, children: [
      // Move body.
      Positioned(
        left: screenTL.dx,
        top: screenTL.dy,
        width: w,
        height: h,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => move(d.delta),
          onTap: () => _showProperties(f),
          child: const SizedBox.expand(),
        ),
      ),
      // Edit (top-left).
      Positioned(
          left: screenTL.dx - 13 - outward,
          top: screenTL.dy - 13 - outward,
          child: circle(Icons.edit, primary, () => _showProperties(f),
              semanticLabel: L10n.of(context).a11yEditField)),
      // Delete (top-right).
      Positioned(
        left: screenTL.dx + w - 13 + outward,
        top: screenTL.dy - 13 - outward,
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
          left: screenTL.dx - 13 - outward,
          top: screenTL.dy + h - 13 + outward,
          child: circle(Icons.add, _groupColor(f.group), () => _addOptionToGroup(f),
              semanticLabel: L10n.of(context).a11yAddOption),
        ),
      // Resize (bottom-right).
      Positioned(
          left: screenTL.dx + w - 13 + outward,
          top: screenTL.dy + h - 13 + outward,
          child: circle(Icons.open_in_full, primary, null,
              onDrag: resize, semanticLabel: L10n.of(context).a11yResizeField)),
    ]);
  }

  // ── Properties (modal sheet, rebuilt per open) ───────────────────────────────

  void _showProperties(EditorField f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.surface))),
      builder: (_) => FieldInspector(
        field: f,
        resolve: (name) => engine.FieldRef(_idForName(name), name),
        onAddOption: _addOptionToGroup,
        optionsInGroup: (g) =>
            _pageFields.values.expand((l) => l).where((x) => x.group == g).length,
        groupLetter: _groupLetter,
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
          tooltip: f.tooltip,
          readOnly: f.readOnly,
          maxLength: f.maxLength > 0 ? f.maxLength : null,
          comb: f.comb,
          alignment: f.alignment,
          multiSelect: f.multiSelect,
          format: formFieldTypes.lookup(f.type.wire)?.defaultFormat ??
              engine.TextFormat.none,
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

    _cancelToken = CancelToken();
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    BlocProvider.of<PdfBloc>(context).add(CreateFormEvent(
      createForm: CreateForm(
        outFileName: 'fillable_${widget.file.path.split('/').last.replaceAll('.pdf', '')}',
        fields: specs,
        file: file,
      ),
      cancelToken: _cancelToken,
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
