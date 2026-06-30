import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/pdf-to-office.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class PdfToOfficeView extends StatefulWidget {
  final File file;
  final PdfOfficeFormat format;

  const PdfToOfficeView({super.key, required this.file, required this.format});

  @override
  State<PdfToOfficeView> createState() => _PdfToOfficeViewState();
}

class _PdfToOfficeViewState extends State<PdfToOfficeView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();
  CancelToken? _cancelToken;

  String get _stateKey {
    switch (widget.format) {
      case PdfOfficeFormat.word: return HttpStates.PDF_TO_WORD;
      case PdfOfficeFormat.excel: return HttpStates.PDF_TO_EXCEL;
      case PdfOfficeFormat.pptx: return HttpStates.PDF_TO_PPTX;
    }
  }

  String get _title {
    switch (widget.format) {
      case PdfOfficeFormat.word: return 'PDF to Word';
      case PdfOfficeFormat.excel: return 'PDF to Excel';
      case PdfOfficeFormat.pptx: return 'PDF to PowerPoint';
    }
  }

  String get _description {
    switch (widget.format) {
      case PdfOfficeFormat.word:
        return 'Extracts text from your PDF and creates a .docx Word document with preserved paragraph structure.';
      case PdfOfficeFormat.excel:
        return 'Extracts text from each PDF page into a separate sheet, splitting columns on whitespace.';
      case PdfOfficeFormat.pptx:
        return 'Creates one PowerPoint slide per PDF page with extracted text in a text box.';
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
      case PdfOfficeFormat.word: return 'Convert to Word';
      case PdfOfficeFormat.excel: return 'Convert to Excel';
      case PdfOfficeFormat.pptx: return 'Convert to PowerPoint';
    }
  }

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[_stateKey] != c.httpStates[_stateKey],
        listenWhen: (p, c) => p.httpStates[_stateKey] != c.httpStates[_stateKey],
        listener: (context, state) {
          final s = state.httpStates[_stateKey];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Converted successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              OpenFile.open((s!.extras!['savedFile'] as File).path);
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
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
                      'Note: Text-extraction based — images and complex layouts are not reproduced.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _outFileNameC,
                      decoration: const InputDecoration(
                        labelText: 'Output File Name',
                        border: OutlineInputBorder(),
                        helperText: 'Extension is added automatically',
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
              LoadingOverlay(
                httpState: state.httpStates[_stateKey],
                label: 'Converting your PDF',
                onCancel: () => _cancelToken?.cancel('cancelled-by-user'),
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
    _bloc.add(PdfToOfficeEvent(
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
