import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/create-form.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'dart:async';

import 'package:form_engine/form_engine.dart' as engine;
import 'package:pdf_craft/services/forms/FormDraftStore.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/theme/app_radius.dart';

enum FieldType { text, multiline, checkbox, radio, dropdown, date, signature }

extension FieldTypeX on FieldType {
  String get label => switch (this) {
        FieldType.text => 'Text',
        FieldType.multiline => 'Paragraph',
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
        FieldType.checkbox => L10n.of(context).fieldCheckbox,
        FieldType.radio => L10n.of(context).fieldRadio,
        FieldType.dropdown => L10n.of(context).fieldDropdown,
        FieldType.date => L10n.of(context).fieldDate,
        FieldType.signature => L10n.of(context).fieldSignature,
      };
  IconData get icon => switch (this) {
        FieldType.text => Icons.text_fields,
        FieldType.multiline => Icons.notes,
        FieldType.checkbox => Icons.check_box_outlined,
        FieldType.radio => Icons.radio_button_checked,
        FieldType.dropdown => Icons.arrow_drop_down_circle_outlined,
        FieldType.date => Icons.calendar_today_outlined,
        FieldType.signature => Icons.draw_outlined,
      };
  String get wire => switch (this) {
        FieldType.text => 'text',
        FieldType.multiline => 'multiline',
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
  bool get isToggle => _descriptor.isToggle;
  bool get hasOptions => _descriptor.acceptsOptions;
  bool get hasValue => _descriptor.acceptsValue;
  bool get isGrouped => _descriptor.isGrouped;
}

/// The field types this app offers. Built once; the engine's registry owns the
/// per-type rules and this is simply the app's handle to it.
final engine.FieldTypeRegistry formFieldTypes =
    engine.FieldTypeRegistry(engine.builtinFieldTypes);

/// A placed form field. [rect] is stored in **fractional** page coordinates
/// (0..1), which makes it independent of zoom and per-page pixel size.
class _Field {
  final String id;
  FieldType type;
  Rect rect;
  String name;
  String value = '';
  List<String> options = ['Option 1', 'Option 2'];
  String group = 'group1';
  String exportValue = '';
  double fontSize = 0;
  bool required = false;
  bool checked = false; // checkbox/radio prefill (on by default)

  _Field({required this.type, required this.rect, required this.name}) : id = UniqueKey().toString();
}

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

  final Map<int, List<_Field>> _pageFields = {};
  final Map<int, Size> _pagePoints = {};
  List<_Field> get _fields => _pageFields[_currentPage] ??= [];

  String? _selectedId;
  int _autoName = 1;

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
              _Field(type: type, rect: Rect.fromLTWH(f.rect.left, f.rect.top, f.rect.width, f.rect.height), name: f.name)
                ..value = f.value
                ..options = List<String>.from(f.options)
                ..group = f.group
                ..exportValue = f.exportValue
                ..fontSize = f.fontSize
                ..required = f.required
                ..checked = f.checked,
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

  _Field? get _selected {
    for (final f in _fields) {
      if (f.id == _selectedId) return f;
    }
    return null;
  }

  int get _totalFields => _pageFields.values.fold(0, (a, b) => a + b.length);

  /// Adds a field of [type] near the page centre, cascaded so successive fields
  /// don't stack exactly on top of one another, then selects it.
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
    left = left.clamp(0.0, 1 - size.width);
    top = top.clamp(0.0, 1 - size.height);
    final field = _Field(type: type, rect: Rect.fromLTWH(left, top, size.width, size.height), name: '${type.wire}_${_autoName++}');
    setState(() {
      _fields.add(field);
      _selectedId = field.id;
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
        final f = _Field(type: type, rect: Rect.fromLTWH(0.12, top, size.width, size.height), name: '${groupName}_${i + 1}');
        if (type == FieldType.radio) {
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
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: L10n.of(context).fitToScreen,
            onPressed: () => setState(() => _tc.value = Matrix4.identity()),
          ),
          // Primary action — enabled once there's at least one field and no
          // submit in flight.
          BlocBuilder<PdfBloc, PdfState>(
            buildWhen: (p, c) => p.httpStates[HttpStates.CREATE_FORM] != c.httpStates[HttpStates.CREATE_FORM],
            builder: (context, state) {
              final busy = state.httpStates[HttpStates.CREATE_FORM]?.loading == true;
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
        buildWhen: (p, c) => p.httpStates[HttpStates.CREATE_FORM] != c.httpStates[HttpStates.CREATE_FORM],
        listenWhen: (p, c) => p.httpStates[HttpStates.CREATE_FORM] != c.httpStates[HttpStates.CREATE_FORM],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.CREATE_FORM];
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
              httpState: state.httpStates[HttpStates.CREATE_FORM],
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

  Widget _fieldVisual(_Field f, double dispW, double dispH, ThemeData theme) {
    final r = Rect.fromLTWH(f.rect.left * dispW, f.rect.top * dispH, f.rect.width * dispW, f.rect.height * dispH);
    final isSel = f.id == _selectedId;
    final primary = theme.colorScheme.primary;
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: primary.withValues(alpha: isSel ? 0.12 : 0.06),
            border: Border.all(color: isSel ? primary : primary.withValues(alpha: 0.45), width: isSel ? 1.8 : 1),
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          // A small type badge in the corner — no inline name label (less noise).
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isSel ? 0.9 : 0.5),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.surface), bottomRight: Radius.circular(AppRadius.surface)),
              ),
              child: Icon(f.type.icon, size: 10, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandles(_Field f, double dispW, double dispH, ThemeData theme) {
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

    Widget circle(IconData icon, Color color, VoidCallback? onTap, {void Function(Offset)? onDrag}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: onDrag == null ? null : (d) => onDrag(d.delta),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          child: Icon(icon, color: Colors.white, size: 14),
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
          child: circle(Icons.edit, primary, () => _showProperties(f))),
      // Delete (top-right).
      Positioned(
        left: screenTL.dx + w - 13 + outward,
        top: screenTL.dy - 13 - outward,
        child: circle(Icons.close, Colors.red, () => setState(() {
              _fields.remove(f);
              _selectedId = null;
            })),
      ),
      // Resize (bottom-right).
      Positioned(
          left: screenTL.dx + w - 13 + outward,
          top: screenTL.dy + h - 13 + outward,
          child: circle(Icons.open_in_full, primary, null, onDrag: resize)),
    ]);
  }

  // ── Properties (modal sheet, rebuilt per open) ───────────────────────────────

  void _showProperties(_Field f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.surface))),
      builder: (_) => _FieldPropertiesSheet(field: f),
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

  Future<void> _onSave() async {
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

/// Properties editor for a single field, opened as a modal sheet. Owns its own
/// controllers (created from the field) so switching fields always shows the
/// correct values, and writes edits straight back to the [field].
class _FieldPropertiesSheet extends StatefulWidget {
  final _Field field;
  const _FieldPropertiesSheet({required this.field});

  @override
  State<_FieldPropertiesSheet> createState() => _FieldPropertiesSheetState();
}

class _FieldPropertiesSheetState extends State<_FieldPropertiesSheet> {
  late final _name = TextEditingController(text: widget.field.name);
  late final _group = TextEditingController(text: widget.field.group);
  late final _export = TextEditingController(text: widget.field.exportValue);
  late final _options = TextEditingController(text: widget.field.options.join(', '));
  late final _value = TextEditingController(text: widget.field.value);
  late final _fontSize = TextEditingController(text: widget.field.fontSize > 0 ? widget.field.fontSize.toStringAsFixed(0) : '');

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    _export.dispose();
    _options.dispose();
    _value.dispose();
    _fontSize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = widget.field;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(f.type.icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(L10n.of(context).typeFieldLabel(f.type.localizedLabel(context)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        _field(_name, L10n.of(context).fieldName, (v) => f.name = v),
        if (f.type == FieldType.radio) ...[
          _field(_group, L10n.of(context).radioGroup, (v) => f.group = v),
          _field(_export, L10n.of(context).optionValue, (v) => f.exportValue = v),
        ],
        if (f.type.hasOptions)
          _field(_options, L10n.of(context).optionsCommaSeparated,
              (v) => f.options = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
        if (f.type.hasValue) _field(_value, L10n.of(context).defaultValue, (v) => f.value = v),
        if (f.type.hasValue)
          _field(_fontSize, 'Font size (0 = auto)', (v) => f.fontSize = double.tryParse(v) ?? 0,
              keyboard: TextInputType.number),
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
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).done)),
        ),
      ]),
    );
  }

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
