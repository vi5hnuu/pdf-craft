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

extension on FieldType {
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
  String group = 'group1';       // radio group
  String exportValue = '';       // radio option value
  double fontSize = 0;
  bool required = false;

  _Field({required this.type, required this.rect, required this.name}) : id = UniqueKey().toString();
}

/// Full PDF form builder: place text / paragraph / checkbox / radio / dropdown /
/// date / signature fields on any page, drag & resize them, edit their
/// properties, zoom in for precision, then export a **real fillable** PDF.
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

  // Per-page fields and per-page PDF-point size (for coordinate conversion).
  final Map<int, List<_Field>> _pageFields = {};
  final Map<int, Size> _pagePoints = {};
  List<_Field> get _fields => _pageFields[_currentPage] ??= [];

  FieldType _tool = FieldType.text;
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

  void _addField() {
    // Sensible default sizes (fractions of the page) per field type.
    final size = switch (_tool) {
      FieldType.multiline => const Size(0.42, 0.12),
      FieldType.checkbox || FieldType.radio => const Size(0.05, 0.032),
      FieldType.signature => const Size(0.32, 0.08),
      _ => const Size(0.36, 0.045),
    };
    final rect = Rect.fromLTWH(0.5 - size.width / 2, 0.44, size.width, size.height);
    final field = _Field(
      type: _tool,
      rect: rect,
      name: '${_tool.wire}_${_autoName++}',
    );
    setState(() {
      _fields.add(field);
      _selectedId = field.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Form Editor${_totalPages > 1 ? ' — P.$_currentPage/$_totalPages' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Reset zoom',
            onPressed: () => setState(() => _tc.value = Matrix4.identity()),
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
          final loading = state.httpStates[HttpStates.CREATE_FORM]?.loading == true;
          return Stack(children: [
            Column(children: [
              _buildToolbar(theme),
              const Divider(height: 1),
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvas(theme),
              ),
              if (_selected != null) _buildProperties(theme, _selected!),
              if (_totalPages > 1) _buildPageNav(theme),
              _buildSaveBar(theme, loading),
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

  Widget _buildToolbar(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              for (final t in FieldType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(t.icon, size: 16, color: _tool == t ? theme.colorScheme.primary : null),
                    label: Text(t.label),
                    selected: _tool == t,
                    onSelected: (_) => setState(() => _tool = t),
                  ),
                ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            onPressed: _addField,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ),
      ]),
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
          child: Stack(children: [
            // Zoomable page + field visuals.
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _tc,
                minScale: 1,
                maxScale: 5,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _selectAt(d.localPosition, dispW, dispH),
                  child: Stack(children: [
                    if (_pageImage != null)
                      Positioned.fill(child: Image.memory(_pageImage!.bytes, fit: BoxFit.fill)),
                    ..._fields.map((f) => _fieldVisual(f, dispW, dispH, theme)),
                  ]),
                ),
              ),
            ),
            // Screen-space edit handles for the selected field (outside the
            // InteractiveViewer, so dragging them never fights with pan/zoom).
            AnimatedBuilder(
              animation: _tc,
              builder: (context, _) {
                final f = _selected;
                if (f == null) return const SizedBox.shrink();
                return _buildHandles(f, dispW, dispH);
              },
            ),
          ]),
        ),
      );
    });
  }

  // Selects the topmost field under a tap (scene coords → fractional).
  void _selectAt(Offset local, double dispW, double dispH) {
    final fx = local.dx / dispW;
    final fy = local.dy / dispH;
    for (final f in _fields.reversed) {
      if (f.rect.contains(Offset(fx, fy))) {
        setState(() => _selectedId = f.id);
        return;
      }
    }
    setState(() => _selectedId = null);
  }

  Widget _fieldVisual(_Field f, double dispW, double dispH, ThemeData theme) {
    final r = Rect.fromLTWH(f.rect.left * dispW, f.rect.top * dispH, f.rect.width * dispW, f.rect.height * dispH);
    final isSel = f.id == _selectedId;
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: isSel ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.5),
              width: isSel ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Icon(f.type.icon, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                f.type == FieldType.radio ? '${f.group}:${f.exportValue.isEmpty ? f.name : f.exportValue}' : f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: theme.colorScheme.primary),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // Draggable move body + resize + delete handles, positioned in screen space
  // via the current InteractiveViewer transform.
  Widget _buildHandles(_Field f, double dispW, double dispH) {
    final scale = _tc.value.getMaxScaleOnAxis();
    final sceneTL = Offset(f.rect.left * dispW, f.rect.top * dispH);
    final screenTL = MatrixUtils.transformPoint(_tc.value, sceneTL);
    final w = f.rect.width * dispW * scale;
    final h = f.rect.height * dispH * scale;

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

    return Stack(children: [
      // Move body.
      Positioned(
        left: screenTL.dx,
        top: screenTL.dy,
        width: w,
        height: h,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => move(d.delta),
          child: const SizedBox.expand(),
        ),
      ),
      // Delete handle.
      Positioned(
        left: screenTL.dx + w - 12,
        top: screenTL.dy - 12,
        child: GestureDetector(
          onTap: () => setState(() {
            _fields.remove(f);
            _selectedId = null;
          }),
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      ),
      // Resize handle (bottom-right).
      Positioned(
        left: screenTL.dx + w - 11,
        top: screenTL.dy + h - 11,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => resize(d.delta),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.open_in_full, color: Colors.white, size: 11),
          ),
        ),
      ),
    ]);
  }

  Widget _buildProperties(ThemeData theme, _Field f) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 168),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(f.type.icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('${f.type.label} properties', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            _propText('Field name', f.name, (v) => setState(() => f.name = v)),
            if (f.type == FieldType.radio) ...[
              _propText('Group', f.group, (v) => setState(() => f.group = v)),
              _propText('Option value', f.exportValue, (v) => setState(() => f.exportValue = v)),
            ],
            if (f.type == FieldType.dropdown)
              _propText('Options (comma-separated)', f.options.join(', '),
                  (v) => setState(() => f.options = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList())),
            if (f.type == FieldType.text || f.type == FieldType.multiline || f.type == FieldType.date)
              _propText('Default value', f.value, (v) => setState(() => f.value = v)),
            Row(children: [
              const Text('Required', style: TextStyle(fontSize: 12)),
              Switch(value: f.required, onChanged: (v) => setState(() => f.required = v)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _propText(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: value,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPageNav(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
        ),
        Text('$_currentPage / $_totalPages'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages ? () => _loadPage(_currentPage + 1) : null,
        ),
      ]),
    );
  }

  Widget _buildSaveBar(ThemeData theme, bool loading) {
    final total = _pageFields.values.fold<int>(0, (a, b) => a + b.length);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: FilledButton.icon(
        onPressed: total > 0 && !loading ? _onSave : null,
        icon: const Icon(Icons.save_alt),
        label: Text(total == 0 ? 'Add fields to continue' : 'Create fillable PDF ($total field${total == 1 ? '' : 's'})'),
      ),
    );
  }

  Future<void> _onSave() async {
    final specs = <FormFieldSpec>[];
    _pageFields.forEach((page, fields) {
      final pts = _pagePoints[page];
      if (pts == null) return;
      for (final f in fields) {
        specs.add(FormFieldSpec(
          type: f.type.wire,
          // Radio options share a field keyed by group; others use their name.
          name: f.type == FieldType.radio ? f.group : f.name,
          page: page - 1,
          x: f.rect.left * pts.width,
          y: f.rect.top * pts.height,
          width: f.rect.width * pts.width,
          height: f.rect.height * pts.height,
          value: f.value.isEmpty ? null : f.value,
          options: f.type == FieldType.dropdown ? f.options : null,
          exportValue: f.type == FieldType.radio ? (f.exportValue.isEmpty ? f.name : f.exportValue) : null,
          fontSize: (f.type == FieldType.text || f.type == FieldType.multiline || f.type == FieldType.date) && f.fontSize > 0
              ? f.fontSize
              : null,
          required: f.required ? true : null,
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

  @override
  void dispose() {
    _tc.dispose();
    _doc?.close();
    super.dispose();
  }
}
