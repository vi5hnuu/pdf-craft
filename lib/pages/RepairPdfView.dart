import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/repair-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

class RepairPdfView extends StatefulWidget {
  final File file;
  const RepairPdfView({super.key, required this.file});

  @override
  State<RepairPdfView> createState() => _RepairPdfViewState();
}

class _RepairPdfViewState extends State<RepairPdfView> {
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
      appBar: AppBar(title: const Text('Repair PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.REPAIR_PDF] != c.httpStates[HttpStates.REPAIR_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.REPAIR_PDF] != c.httpStates[HttpStates.REPAIR_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.REPAIR_PDF];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'PDF repaired successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Repairing PDF...', color: Colors.lightBlue);
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
                            // Info chip showing the selected file
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                              'Repair attempts to fix common PDF corruption issues such as broken cross-references, malformed streams, and invalid object structures.',
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _onRepair,
                        icon: const Icon(Icons.build),
                        label: const Text('Repair PDF'),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isLoading(forr: HttpStates.REPAIR_PDF))
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

  void _onRepair() async {
    _bloc.add(RepairPdfEvent(
      repairPdf: RepairPdf(
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
