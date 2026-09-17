import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/pdf_to_office.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

class PdfToOfficeView extends StatefulWidget {
  final File file;
  final PdfOfficeFormat format;

  const PdfToOfficeView({super.key, required this.file, required this.format});

  @override
  State<PdfToOfficeView> createState() => _PdfToOfficeViewState();
}

class _PdfToOfficeViewState extends State<PdfToOfficeView>
    with ToolResultHandler, ToolViewMixin {
  final TextEditingController _outFileNameC = TextEditingController();
  CancelToken? _cancelToken;

  String get _stateKey {
    switch (widget.format) {
      case PdfOfficeFormat.word: return HttpStates.pdfToWord;
      case PdfOfficeFormat.excel: return HttpStates.pdfToExcel;
      case PdfOfficeFormat.pptx: return HttpStates.pdfToPptx;
    }
  }

  String get _title {
    switch (widget.format) {
      case PdfOfficeFormat.word: return ToolStrings.name(context, 'pdf-to-word');
      case PdfOfficeFormat.excel: return ToolStrings.name(context, 'pdf-to-excel');
      case PdfOfficeFormat.pptx: return ToolStrings.name(context, 'pdf-to-pptx');
    }
  }

  String get _description {
    switch (widget.format) {
      case PdfOfficeFormat.word:
        return L10n.of(context).pdfToWordDesc;
      case PdfOfficeFormat.excel:
        return L10n.of(context).pdfToExcelDesc;
      case PdfOfficeFormat.pptx:
        return L10n.of(context).pdfToPptxDesc;
    }
  }

  String get _defaultName {
    switch (widget.format) {
      case PdfOfficeFormat.word: return 'converted_document';
      case PdfOfficeFormat.excel: return 'converted_spreadsheet';
      case PdfOfficeFormat.pptx: return 'converted_presentation';
    }
  }

  String get _buttonLabel {
    switch (widget.format) {
      case PdfOfficeFormat.word: return L10n.of(context).convertToWord;
      case PdfOfficeFormat.excel: return L10n.of(context).convertToExcel;
      case PdfOfficeFormat.pptx: return L10n.of(context).convertToPowerPoint;
    }
  }

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.pdfToExcel, HttpStates.pdfToPptx, HttpStates.pdfToWord]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[_stateKey] != c.httpStates[_stateKey],
        listenWhen: (p, c) => p.httpStates[_stateKey] != c.httpStates[_stateKey],
        // The output is a Word/Excel/PowerPoint file, so it opens externally.
        listener: (context, state) => handleToolState(
              state.httpStates[_stateKey],
              successMessage: L10n.current.toolDone,
              onDone: (saved) => OpenFile.open(saved.path),
            ),
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_description, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      L10n.of(context).officeNote,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _outFileNameC,
                      decoration: InputDecoration(
                        labelText: L10n.of(context).outputFileName,
                        border: const OutlineInputBorder(),
                        helperText: L10n.of(context).extensionAutoAdded,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: _onConvert, child: Text(_buttonLabel)),
                    ),
                  ],
                ),
              ),
              processingOverlay(state.httpStates[_stateKey],
                label: L10n.of(context).convertingPdf,
              ),
            ],
          );
        },
      ),
    );
  }

  void _onConvert() async {
    final name = _outFileNameC.text.trim().isEmpty ? _defaultName : _outFileNameC.text.trim();
    _cancelToken = CancelToken();
    final file = await MultipartFile.fromFile(widget.file.path);
    runTool((cancelToken) => PdfToOfficeEvent(
      pdfToOffice: PdfToOffice(
        outFileName: name,
        format: widget.format,
        file: file,
      ),
      cancelToken: _cancelToken,
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    super.dispose();
  }
}
