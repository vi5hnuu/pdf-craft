import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/extract-embedded-files.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Extract Embedded Files: pulls file attachments out of the PDF into a ZIP.
class ExtractEmbeddedFilesView extends StatefulWidget {
  final File file;
  const ExtractEmbeddedFilesView({super.key, required this.file});

  @override
  State<ExtractEmbeddedFilesView> createState() => _ExtractEmbeddedFilesViewState();
}

class _ExtractEmbeddedFilesViewState extends State<ExtractEmbeddedFilesView>
    with ToolResultHandler, ToolViewMixin {
  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.EXTRACT_EMBEDDED]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Embedded Files')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_EMBEDDED] != c.httpStates[HttpStates.EXTRACT_EMBEDDED],
        listenWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_EMBEDDED] != c.httpStates[HttpStates.EXTRACT_EMBEDDED],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.EXTRACT_EMBEDDED],
          successMessage: 'Embedded files extracted',
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.EXTRACT_EMBEDDED]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.attachment_outlined, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Extract attachments',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Some PDFs carry attached files (spreadsheets, other PDFs, etc.). '
                      'These are collected into a ZIP. If there are none, you\'ll be told.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4),
                    ),
                  ]),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton.icon(
                  onPressed: loading ? null : _onExtract,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Extract Files (ZIP)'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.EXTRACT_EMBEDDED], label: 'Extracting files'),
          ]);
        },
      ),
    );
  }

  Future<void> _onExtract() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ExtractEmbeddedFilesEvent(
          extractEmbeddedFiles: ExtractEmbeddedFiles(file: file),
          cancelToken: cancelToken,
        ));
  }
}
