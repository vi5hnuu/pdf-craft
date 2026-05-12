import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/extract-text.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class ExtractTextView extends StatefulWidget {
  final File file;

  const ExtractTextView({super.key, required this.file});

  @override
  State<ExtractTextView> createState() => _ExtractTextViewState();
}

class _ExtractTextViewState extends State<ExtractTextView> {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Text'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_TEXT] != c.httpStates[HttpStates.EXTRACT_TEXT],
        listenWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_TEXT] != c.httpStates[HttpStates.EXTRACT_TEXT],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.EXTRACT_TEXT];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Text extracted successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              OpenFile.open((s!.extras!['savedFile'] as File).path);
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Extracting text...', color: Colors.lightBlue);
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
                    const Text(
                      'Extract all text content from your PDF into a text file.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _outFileNameC,
                      decoration: const InputDecoration(labelText: 'Output File Name', border: OutlineInputBorder()),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: _onExtract, child: const Text('Extract Text')),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.EXTRACT_TEXT]),
            ],
          );
        },
      ),
    );
  }

  void _onExtract() async {
    bloc.add(ExtractTextEvent(
      extractText: ExtractText(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'extracted_text',
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
