import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/fill_flatten.dart';
import 'package:pdf_craft/models/request/flatten_pdf.dart';
import 'package:pdf_craft/models/request/get_form_fields.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// Flatten PDF. If the PDF already has fillable form fields, they're listed so
/// the user can fill them and flatten in one step; otherwise it's a plain flatten.
class FlattenPdfView extends StatefulWidget {
  final File file;
  const FlattenPdfView({super.key, required this.file});

  @override
  State<FlattenPdfView> createState() => _FlattenPdfViewState();
}

class _FlattenPdfViewState extends State<FlattenPdfView>
    with ToolResultHandler, ToolViewMixin {
  final TextEditingController _outFileNameC = TextEditingController();

  List<Map<String, dynamic>>? _fields; // null = still loading
  final Map<String, String> _values = {};

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFields());
    resetToolState([HttpStates.fillFlatten, HttpStates.flattenPdf, HttpStates.getFormFields]);
  }

  Future<void> _loadFields() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => GetFormFieldsEvent(getFormFields: GetFormFields(file: uploadFile), cancelToken: cancelToken));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'flatten'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.flattenPdf] != c.httpStates[HttpStates.flattenPdf] ||
            p.httpStates[HttpStates.fillFlatten] != c.httpStates[HttpStates.fillFlatten] ||
            p.httpStates[HttpStates.getFormFields] != c.httpStates[HttpStates.getFormFields],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.flattenPdf] != c.httpStates[HttpStates.flattenPdf] ||
            p.httpStates[HttpStates.fillFlatten] != c.httpStates[HttpStates.fillFlatten] ||
            p.httpStates[HttpStates.getFormFields] != c.httpStates[HttpStates.getFormFields],
        listener: (context, state) {
          // Populate the discovered fields.
          final gs = state.httpStates[HttpStates.getFormFields];
          if (gs?.done == true && _fields == null) {
            final raw = gs?.extras?['fields'];
            setState(() => _fields = (raw is List) ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : []);
            for (final f in _fields!) {
              final name = f['name']?.toString();
              if (name != null) _values[name] = f['value']?.toString() ?? '';
            }
          } else if (gs?.error != null && _fields == null) {
            setState(() => _fields = []); // fall back to plain flatten
          }

          // Navigate on either flatten path completing. Each key is cleared once handled, so a
          // finished run cannot announce itself again when the other path later completes.
          for (final key in [HttpStates.flattenPdf, HttpStates.fillFlatten]) {
            final fs = state.httpStates[key];
            if (fs?.done != true && fs?.error == null) continue;
            handleToolState(fs, successMessage: L10n.current.toolDone);
            resetToolState([key]);
          }
        },
        builder: (context, state) {
          final busy = _isBusy(state);
          return Stack(children: [
            _fields == null ? const Center(child: CircularProgressIndicator()) : _buildBody(theme, busy),
            processingOverlay(state.httpStates[HttpStates.fillFlatten]?.loading == true
                  ? state.httpStates[HttpStates.fillFlatten]
                  : state.httpStates[HttpStates.flattenPdf],
              label: L10n.of(context).flatteningPdf,
            ),
          ]);
        },
      ),
    );
  }

  bool _isBusy(PdfState s) =>
      s.httpStates[HttpStates.flattenPdf]?.loading == true || s.httpStates[HttpStates.fillFlatten]?.loading == true;

  Widget _buildBody(ThemeData theme, bool busy) {
    final hasFields = _fields != null && _fields!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _outFileNameC,
                decoration: InputDecoration(labelText: L10n.of(context).outputFileNameOptional, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              if (hasFields) ...[
                Text(L10n.of(context).flattenFieldsCount(_fields!.length),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(L10n.of(context).flattenHint,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 12),
                ..._fields!.map((f) => _buildFieldInput(theme, f)),
              ] else
                Text(
                  L10n.of(context).flattenExplainer,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
            ]),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : (hasFields ? _onFillFlatten : _onFlatten),
            icon: const Icon(Icons.layers_clear),
            label: Text(hasFields ? L10n.of(context).fillAndFlatten : ToolStrings.name(context, 'flatten')),
          ),
        ),
      ]),
    );
  }

  Widget _buildFieldInput(ThemeData theme, Map<String, dynamic> f) {
    final name = f['name']?.toString() ?? '';
    final type = f['type']?.toString() ?? 'text';
    final options = (f['options'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final current = _values[name] ?? '';

    Widget control;
    switch (type) {
      case 'checkbox':
        final on = current.toLowerCase() == 'yes' || current.toLowerCase() == 'on' || current == '1' || current.toLowerCase() == 'true';
        control = SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name, style: const TextStyle(fontSize: 13)),
          value: on,
          onChanged: (v) => setState(() => _values[name] = v ? 'Yes' : 'Off'),
        );
        break;
      case 'radio':
      case 'dropdown':
        control = InputDecorator(
          decoration: InputDecoration(labelText: name, border: const OutlineInputBorder(), isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: options.contains(current) ? current : null,
              hint: Text(L10n.of(context).select),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) => setState(() => _values[name] = v ?? ''),
            ),
          ),
        );
        break;
      case 'signature':
        control = ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.draw_outlined),
          title: Text(name),
          subtitle: Text(L10n.of(context).signatureNotFillable),
        );
        break;
      default: // text
        control = TextFormField(
          initialValue: current,
          decoration: InputDecoration(labelText: name, border: const OutlineInputBorder(), isDense: true),
          onChanged: (v) => _values[name] = v,
        );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: control);
  }

  void _onFlatten() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => FlattenPdfEvent(
      flattenPdf: FlattenPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  void _onFillFlatten() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => FillFlattenEvent(
      fillFlatten: FillFlatten(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        values: Map<String, String>.from(_values),
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    super.dispose();
  }
}
