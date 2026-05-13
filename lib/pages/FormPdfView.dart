import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_craft/models/request/stamp-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

// ── Field model ───────────────────────────────────────────────────────────────

enum _FieldType { text, checkbox, date }

class _FormField {
  final _FieldType type;
  Offset position;   // fraction of canvas width/height
  String value;
  bool checked;
  final String id;

  _FormField({
    required this.type,
    required this.position,
    this.value = '',
    this.checked = false,
  }) : id = UniqueKey().toString();
}

// ── View ──────────────────────────────────────────────────────────────────────

class FormPdfView extends StatefulWidget {
  final File file;
  const FormPdfView({super.key, required this.file});

  @override
  State<FormPdfView> createState() => _FormPdfViewState();
}

class _FormPdfViewState extends State<FormPdfView> {
  PdfDocument? _doc;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfPageImage? _pageImage;
  bool _loadingPage = true;

  // Form fields placed on current page (keyed by page number)
  final Map<int, List<_FormField>> _pageFields = {};
  List<_FormField> get _fields => _pageFields[_currentPage] ??= [];

  _FieldType _activeTool = _FieldType.text;
  String? _selectedFieldId;
  final GlobalKey _overlayKey = GlobalKey();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _openDocument();
  }

  Future<void> _openDocument() async {
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
        _selectedFieldId = null;
        _loadingPage = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Form Fill${_totalPages > 1 ? ' — Page $_currentPage / $_totalPages' : ''}'),
        actions: [
          if (_fields.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear page fields',
              onPressed: () => setState(() {
                _fields.clear();
                _selectedFieldId = null;
              }),
            ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.STAMP_PDF];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(
                text: 'Form fields applied', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {
                  'pdfFilePath': (s!.extras!['savedFile'] as File).path
                },
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(
                text: 'Applying fields…', color: Colors.lightBlue);
          }
        },
        builder: (context, state) {
          return Stack(children: [
            Column(children: [
              // ── Field type toolbar ────────────────────────────────────
              _buildToolbar(theme),
              const Divider(height: 1),
              Text(
                'Tap on the page to place a field. Drag fields to reposition.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // ── Canvas ────────────────────────────────────────────────
              Expanded(
                child: _loadingPage
                    ? const Center(child: CircularProgressIndicator())
                    : _buildCanvas(theme),
              ),

              // ── Page navigation ───────────────────────────────────────
              if (_totalPages > 1) _buildPageNav(theme),

              // ── Save bar ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton.icon(
                  onPressed: _hasAnyFields && !_saving ? _onSave : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_alt),
                  label: Text(_saving ? 'Applying…' : 'Apply Fields to PDF'),
                ),
              ),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.STAMP_PDF]),
          ]);
        },
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        _toolBtn(_FieldType.text, Icons.text_fields, 'Text Field', theme),
        _toolBtn(_FieldType.checkbox, Icons.check_box_outlined, 'Checkbox', theme),
        _toolBtn(_FieldType.date, Icons.calendar_today_outlined, 'Date', theme),
      ]),
    );
  }

  Widget _toolBtn(_FieldType t, IconData icon, String label, ThemeData theme) {
    final active = _activeTool == t;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(icon, size: 16,
            color: active ? theme.colorScheme.primary : null),
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _activeTool = t),
      ),
    );
  }

  Widget _buildCanvas(ThemeData theme) {
    return LayoutBuilder(builder: (context, constraints) {
      final canvasW = constraints.maxWidth;
      final canvasH = constraints.maxHeight;

      return GestureDetector(
        // Tap on canvas background to place new field
        onTapUp: (d) {
          final pos = Offset(
            d.localPosition.dx / canvasW,
            d.localPosition.dy / canvasH,
          );
          // Deselect if tap near no existing field
          setState(() {
            _selectedFieldId = null;
            _fields.add(_FormField(type: _activeTool, position: pos));
          });
        },
        child: Stack(children: [
          // Page image
          if (_pageImage != null)
            Positioned.fill(
              child: Image.memory(_pageImage!.bytes, fit: BoxFit.contain),
            )
          else
            Positioned.fill(child: Container(color: Colors.white)),

          // Overlay capture boundary (transparent — fields only)
          Positioned.fill(
            child: RepaintBoundary(
              key: _overlayKey,
              child: Stack(
                children: _fields.map((field) {
                  return _FieldWidget(
                    field: field,
                    canvasW: canvasW,
                    canvasH: canvasH,
                    selected: _selectedFieldId == field.id,
                    onSelect: () => setState(() => _selectedFieldId = field.id),
                    onDrag: (delta) => setState(() {
                      field.position = Offset(
                        (field.position.dx + delta.dx / canvasW).clamp(0.0, 1.0),
                        (field.position.dy + delta.dy / canvasH).clamp(0.0, 1.0),
                      );
                    }),
                    onDelete: () => setState(() {
                      _fields.remove(field);
                      _selectedFieldId = null;
                    }),
                    onValueChanged: (v) => setState(() => field.value = v),
                    onCheckToggle: () => setState(() => field.checked = !field.checked),
                  );
                }).toList(),
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _buildPageNav(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
          ),
          Text('$_currentPage / $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages ? () => _loadPage(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  bool get _hasAnyFields =>
      _pageFields.values.any((fields) => fields.isNotEmpty);

  Future<void> _onSave() async {
    if (!_hasAnyFields) return;
    setState(() => _saving = true);
    try {
      final boundary = _overlayKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not capture fields');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode field image');

      final tmpDir = await getTemporaryDirectory();
      final stampFile = File(
          '${tmpDir.path}/form_overlay_${DateTime.now().millisecondsSinceEpoch}.png');
      await stampFile.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;

      BlocProvider.of<PdfBloc>(context).add(StampPdfEvent(
        stampPdf: StampPdf(
          outFileName:
              'filled_${widget.file.path.split('/').last.replaceAll('.pdf', '')}',
          opacity: 1.0,
          fromPage: _currentPage - 1,
          toPage: _currentPage - 1,
          file: await MultipartFile.fromFile(widget.file.path),
          stamp: await MultipartFile.fromFile(stampFile.path,
              contentType: DioMediaType.parse('image/png')),
        ),
      ));
    } catch (e) {
      NotificationService.showSnackbar(
          text: 'Failed to apply fields: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }
}

// ── Individual field widget ───────────────────────────────────────────────────

class _FieldWidget extends StatelessWidget {
  final _FormField field;
  final double canvasW, canvasH;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(Offset delta) onDrag;
  final VoidCallback onDelete;
  final void Function(String) onValueChanged;
  final VoidCallback onCheckToggle;

  const _FieldWidget({
    required this.field,
    required this.canvasW,
    required this.canvasH,
    required this.selected,
    required this.onSelect,
    required this.onDrag,
    required this.onDelete,
    required this.onValueChanged,
    required this.onCheckToggle,
  });

  @override
  Widget build(BuildContext context) {
    final left = field.position.dx * canvasW;
    final top = field.position.dy * canvasH;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: onSelect,
        onPanUpdate: (d) => onDrag(d.delta),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildFieldContent(context),
            if (selected)
              Positioned(
                top: -10, right: -10,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldContent(BuildContext context) {
    switch (field.type) {
      case _FieldType.text:
        return _TextFieldWidget(
          value: field.value,
          selected: selected,
          onChanged: onValueChanged,
        );
      case _FieldType.checkbox:
        return _CheckboxWidget(
          checked: field.checked,
          selected: selected,
          onToggle: onCheckToggle,
        );
      case _FieldType.date:
        return _DateFieldWidget(
          value: field.value,
          selected: selected,
          onChanged: onValueChanged,
        );
    }
  }
}

class _TextFieldWidget extends StatefulWidget {
  final String value;
  final bool selected;
  final void Function(String) onChanged;
  const _TextFieldWidget({required this.value, required this.selected, required this.onChanged});

  @override
  State<_TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<_TextFieldWidget> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(
            color: widget.selected ? Colors.blue : Colors.black54, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: _c,
        style: const TextStyle(fontSize: 13, color: Colors.black),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: InputBorder.none,
          hintText: 'Text…',
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _CheckboxWidget extends StatelessWidget {
  final bool checked;
  final bool selected;
  final VoidCallback onToggle;
  const _CheckboxWidget({required this.checked, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border.all(
              color: selected ? Colors.blue : Colors.black54, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: checked
            ? const Icon(Icons.check, color: Colors.black, size: 22)
            : null,
      ),
    );
  }
}

class _DateFieldWidget extends StatefulWidget {
  final String value;
  final bool selected;
  final void Function(String) onChanged;
  const _DateFieldWidget({required this.value, required this.selected, required this.onChanged});

  @override
  State<_DateFieldWidget> createState() => _DateFieldWidgetState();
}

class _DateFieldWidgetState extends State<_DateFieldWidget> {
  late String _date;

  @override
  void initState() {
    super.initState();
    _date = widget.value.isEmpty
        ? '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'
        : widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          final formatted = '${picked.day}/${picked.month}/${picked.year}';
          setState(() => _date = formatted);
          widget.onChanged(formatted);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border.all(
              color: widget.selected ? Colors.blue : Colors.black54, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.black54),
            const SizedBox(width: 4),
            Text(_date, style: const TextStyle(fontSize: 12, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
