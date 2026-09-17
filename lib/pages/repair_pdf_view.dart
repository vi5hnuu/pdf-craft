import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/repair_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class RepairPdfView extends StatefulWidget {
  final File file;
  const RepairPdfView({super.key, required this.file});

  @override
  State<RepairPdfView> createState() => _RepairPdfViewState();
}

class _RepairPdfViewState extends State<RepairPdfView>
    with ToolResultHandler, ToolViewMixin {
  final TextEditingController _outFileNameC = TextEditingController();
  CancelToken? _cancelToken;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    resetToolState([HttpStates.repairPdf]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'repair')), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.repairPdf] != c.httpStates[HttpStates.repairPdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.repairPdf] != c.httpStates[HttpStates.repairPdf],
        listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.repairPdf], successMessage: L10n.current.toolDone),
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
                                borderRadius: BorderRadius.circular(AppRadius.surface),
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
                              decoration: InputDecoration(labelText: L10n.of(context).outputFileNameOptional, border: const OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              L10n.of(context).repairExplainer,
                              style: const TextStyle(fontSize: 13, height: 1.5),
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
                        label: Text(ToolStrings.name(context, 'repair')),
                      ),
                    ),
                  ],
                ),
              ),
              processingOverlay(state.httpStates[HttpStates.repairPdf], label: L10n.of(context).procWorking),
            ],
          );
        },
      ),
    );
  }

  void _onRepair() async {
    _cancelToken = CancelToken();
    final file = await MultipartFile.fromFile(widget.file.path);
    runTool((cancelToken) => RepairPdfEvent(
      repairPdf: RepairPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
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
