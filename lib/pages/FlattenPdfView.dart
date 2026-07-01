import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/fill-flatten.dart';
import 'package:pdf_craft/models/request/flatten-pdf.dart';
import 'package:pdf_craft/models/request/get-form-fields.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

/// Flatten PDF. If the PDF already has fillable form fields, they're listed so
/// the user can fill them and flatten in one step; otherwise it's a plain flatten.
class FlattenPdfView extends StatefulWidget {
  final File file;
  const FlattenPdfView({super.key, required this.file});

  @override
  State<FlattenPdfView> createState() => _FlattenPdfViewState();
}

class _FlattenPdfViewState extends State<FlattenPdfView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();

  List<Map<String, dynamic>>? _fields; // null = still loading
  final Map<String, String> _values = {};

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFields());
  }

  Future<void> _loadFields() async {
    _bloc.add(GetFormFieldsEvent(getFormFields: GetFormFields(file: await MultipartFile.fromFile(widget.file.path))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Flatten PDF')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.FLATTEN_PDF] != c.httpStates[HttpStates.FLATTEN_PDF] ||
            p.httpStates[HttpStates.FILL_FLATTEN] != c.httpStates[HttpStates.FILL_FLATTEN] ||
            p.httpStates[HttpStates.GET_FORM_FIELDS] != c.httpStates[HttpStates.GET_FORM_FIELDS],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.FLATTEN_PDF] != c.httpStates[HttpStates.FLATTEN_PDF] ||
            p.httpStates[HttpStates.FILL_FLATTEN] != c.httpStates[HttpStates.FILL_FLATTEN] ||
            p.httpStates[HttpStates.GET_FORM_FIELDS] != c.httpStates[HttpStates.GET_FORM_FIELDS],
        listener: (context, state) {
          // Populate the discovered fields.
          final gs = state.httpStates[HttpStates.GET_FORM_FIELDS];
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

          // Navigate on either flatten path completing.
          for (final key in [HttpStates.FLATTEN_PDF, HttpStates.FILL_FLATTEN]) {
            final s = state.httpStates[key];
            if (s?.done == true) {
              AdsSingleton().dispatch(ShowInterstitialAd());
              NotificationService.showSnackbar(text: 'PDF flattened successfully', color: Colors.green);
              if (s?.extras?['savedFile'] is File) {
                GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,
                    pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
              }
            } else if (s?.error != null) {
              NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
            }
          }
        },
        builder: (context, state) {
          final busy = _isBusy(state);
          return Stack(children: [
            _fields == null ? const Center(child: CircularProgressIndicator()) : _buildBody(theme, busy),
            LoadingOverlay(
              httpState: state.httpStates[HttpStates.FILL_FLATTEN]?.loading == true
                  ? state.httpStates[HttpStates.FILL_FLATTEN]
                  : state.httpStates[HttpStates.FLATTEN_PDF],
              label: 'Flattening your PDF',
            ),
          ]);
        },
      ),
    );
  }

  bool _isBusy(PdfState s) =>
      s.httpStates[HttpStates.FLATTEN_PDF]?.loading == true || s.httpStates[HttpStates.FILL_FLATTEN]?.loading == true;

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
                decoration: const InputDecoration(labelText: 'Output File Name (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              if (hasFields) ...[
                Text('This PDF has ${_fields!.length} fillable field${_fields!.length == 1 ? '' : 's'}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Fill any you like, then flatten to bake the values in permanently.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 12),
                ..._fields!.map((f) => _buildFieldInput(theme, f)),
              ] else
                const Text(
                  'Flattening merges interactive form fields and annotations into static page content. '
                  'The result is no longer editable but displays consistently everywhere.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
            ]),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : (hasFields ? _onFillFlatten : _onFlatten),
            icon: const Icon(Icons.layers_clear),
            label: Text(hasFields ? 'Fill & Flatten' : 'Flatten PDF'),
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
              hint: const Text('Select'),
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
          subtitle: const Text('Signature field — not fillable here'),
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
    _bloc.add(FlattenPdfEvent(
      flattenPdf: FlattenPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  void _onFillFlatten() async {
    _bloc.add(FillFlattenEvent(
      fillFlatten: FillFlatten(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        values: Map<String, String>.from(_values),
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    super.dispose();
  }
}
