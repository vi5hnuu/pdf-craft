import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/grayscale-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class GrayscalePdfView extends StatefulWidget {
  final File file;

  const GrayscalePdfView({super.key, required this.file});

  @override
  State<GrayscalePdfView> createState() => _GrayscalePdfViewState();
}

class _GrayscalePdfViewState extends State<GrayscalePdfView> {
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
      appBar: AppBar(title: const Text('Grayscale PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.GRAYSCALE_PDF] != c.httpStates[HttpStates.GRAYSCALE_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.GRAYSCALE_PDF] != c.httpStates[HttpStates.GRAYSCALE_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.GRAYSCALE_PDF];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'PDF converted to grayscale', color: Colors.green);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Convert all pages of your PDF to grayscale to reduce file size and ink usage when printing.',
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
                      child: FilledButton(onPressed: _onGrayscale, child: const Text('Convert to Grayscale')),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.GRAYSCALE_PDF], label: 'Converting to grayscale'),
            ],
          );
        },
      ),
    );
  }

  void _onGrayscale() async {
    bloc.add(GrayscalePdfEvent(
      grayscalePdf: GrayscalePdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'grayscale_file',
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
