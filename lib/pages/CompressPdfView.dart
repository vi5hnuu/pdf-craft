import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/enums/compression-level.dart';
import 'package:pdf_craft/models/request/compress-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class CompressPdfView extends StatefulWidget {
  final File file;

  const CompressPdfView({super.key, required this.file});

  @override
  State<CompressPdfView> createState() => _CompressPdfViewState();
}

class _CompressPdfViewState extends State<CompressPdfView> {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();
  CompressionLevel _level = CompressionLevel.RECOMMENDED;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.COMPRESS_PDF] != c.httpStates[HttpStates.COMPRESS_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.COMPRESS_PDF] != c.httpStates[HttpStates.COMPRESS_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.COMPRESS_PDF];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'PDF compressed successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
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
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _outFileNameC,
                              decoration: const InputDecoration(labelText: 'Output File Name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 24),
                            const Text('Compression Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ...CompressionLevel.values.map((level) => RadioListTile<CompressionLevel>(
                              title: Text(level.displayName),
                              value: level,
                              groupValue: _level,
                              onChanged: (v) => setState(() => _level = v!),
                            )),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _onCompress,
                        child: const Text('Compress PDF'),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.COMPRESS_PDF], label: 'Compressing your PDF'),
            ],
          );
        },
      ),
    );
  }

  void _onCompress() async {
    bloc.add(CompressPdfEvent(
      compressPdf: CompressPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'compressed_file',
        level: _level,
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
