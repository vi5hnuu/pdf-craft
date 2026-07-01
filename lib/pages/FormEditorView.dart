import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/create-form.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

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

  // ── Per-type config (single source of truth — adding a type touches only here) ──
  Size get defaultSize => switch (this) {
        FieldType.multiline => const Size(0.42, 0.12),
        FieldType.checkbox || FieldType.radio => const Size(0.05, 0.032),
        FieldType.signature => const Size(0.32, 0.08),
        _ => const Size(0.36, 0.045),
      };
  bool get isToggle => this == FieldType.checkbox || this == FieldType.radio;
  bool get hasOptions => this == FieldType.dropdown;
  bool get hasValue => this == FieldType.text || this == FieldType.multiline || this == FieldType.date;
}

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

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _open();
  }

  Future<void> _open() async {
    try {
      _doc = await PdfDocument.openFile(widget.file.path);
      _totalPages = _doc!.pagesCount;
      await _loadPage(1);
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
    final step = _fields.length % 6;
    final left = (0.12 + step * 0.03).clamp(0.0, 1 - size.width);
    final top = (0.18 + step * 0.05).clamp(0.0, 1 - size.height);
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
        title: Text('${type.label} group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter option labels, separated by commas.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
            child: const Text('Add'),
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
        title: const Text('Form Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: 'Fit to screen',
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
                  child: const Text('Create'),
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
            NotificationService.showSnackbar(text: 'Fillable form created', color: Colors.green);
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
              label: 'Creating fillable form',
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Tap a field below to place it',
                  style: TextStyle(fontSize: 12.5, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
    ]);
  }

  Widget _pagePill(ThemeData theme) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(3),
          ),
          // A small type badge in the corner — no inline name label (less noise).
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isSel ? 0.9 : 0.5),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), bottomRight: Radius.circular(4)),
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
      Positioned(left: screenTL.dx - 13, top: screenTL.dy - 13, child: circle(Icons.edit, primary, () => _showProperties(f))),
      // Delete (top-right).
      Positioned(
        left: screenTL.dx + w - 13,
        top: screenTL.dy - 13,
        child: circle(Icons.close, Colors.red, () => setState(() {
              _fields.remove(f);
              _selectedId = null;
            })),
      ),
      // Resize (bottom-right).
      Positioned(left: screenTL.dx + w - 13, top: screenTL.dy + h - 13, child: circle(Icons.open_in_full, primary, null, onDrag: resize)),
    ]);
  }

  // ── Properties (modal sheet, rebuilt per open) ───────────────────────────────

  void _showProperties(_Field f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FieldPropertiesSheet(field: f),
    ).whenComplete(() {
      if (mounted) setState(() {}); // refresh badges/state after edits
    });
  }

  Future<void> _onSave() async {
    final specs = <FormFieldSpec>[];
    _pageFields.forEach((page, fields) {
      final pts = _pagePoints[page];
      if (pts == null) return;
      for (final f in fields) {
        specs.add(FormFieldSpec(
          type: f.type.wire,
          name: f.type == FieldType.radio ? f.group : f.name,
          page: page - 1,
          x: f.rect.left * pts.width,
          y: f.rect.top * pts.height,
          width: f.rect.width * pts.width,
          height: f.rect.height * pts.height,
          value: f.value.isEmpty ? null : f.value,
          options: f.type == FieldType.dropdown ? f.options : null,
          exportValue: f.type == FieldType.radio ? (f.exportValue.isEmpty ? f.name : f.exportValue) : null,
          fontSize: f.type.hasValue && f.fontSize > 0 ? f.fontSize : null,
          required: f.required ? true : null,
          checked: f.type.isToggle ? f.checked : null,
        ));
      }
    });

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
              _paletteGroupItem(theme, FieldType.radio, 'Radio group', Icons.radio_button_checked),
              _paletteGroupItem(theme, FieldType.checkbox, 'Check group', Icons.checklist),
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => _promptGroup(t),
        child: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => _addField(t),
        child: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t.icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(t.label, style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
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
          Text('${f.type.label} field', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        _field(_name, 'Field name', (v) => f.name = v),
        if (f.type == FieldType.radio) ...[
          _field(_group, 'Radio group', (v) => f.group = v),
          _field(_export, 'Option value', (v) => f.exportValue = v),
        ],
        if (f.type.hasOptions)
          _field(_options, 'Options (comma-separated)',
              (v) => f.options = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
        if (f.type.hasValue) _field(_value, 'Default value', (v) => f.value = v),
        if (f.type.hasValue)
          _field(_fontSize, 'Font size (0 = auto)', (v) => f.fontSize = double.tryParse(v) ?? 0,
              keyboard: TextInputType.number),
        if (f.type.isToggle)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.type == FieldType.radio ? 'Selected by default' : 'Checked by default'),
            value: f.checked,
            onChanged: (v) => setState(() => f.checked = v),
          ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Required'),
          value: f.required,
          onChanged: (v) => setState(() => f.required = v),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
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
