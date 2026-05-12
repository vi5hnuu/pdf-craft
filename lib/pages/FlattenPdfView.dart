import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/flatten-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

class FlattenPdfView extends StatefulWidget {
  final File file;
  const FlattenPdfView({super.key, required this.file});

  @override
  State<FlattenPdfView> createState() => _FlattenPdfViewState();
}

class _FlattenPdfViewState extends State<FlattenPdfView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flatten PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.FLATTEN_PDF] != c.httpStates[HttpStates.FLATTEN_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.FLATTEN_PDF] != c.httpStates[HttpStates.FLATTEN_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.FLATTEN_PDF];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'PDF flattened successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Flattening PDF...', color: Colors.lightBlue);
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
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(widget.file.path.split('/').last, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _outFileNameC,
                              decoration: const InputDecoration(labelText: 'Output File Name (optional)', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Flattening merges interactive form fields and annotations into static page content. The resulting PDF will no longer be editable but will display consistently on all viewers.',
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _onFlatten,
                        icon: const Icon(Icons.layers_clear),
                        label: const Text('Flatten PDF'),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isLoading(forr: HttpStates.FLATTEN_PDF))
                Container(
                  color: Colors.black54.withValues(alpha: 0.6),
                  child: const Center(child: SpinKitThreeBounce(color: Colors.green, size: 45)),
                ),
            ],
          );
        },
      ),
    );
  }

  void _onFlatten() async {
    _bloc.add(FlattenPdfEvent(
      flattenPdf: FlattenPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
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
