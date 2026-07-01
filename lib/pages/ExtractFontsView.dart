import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/extract-fonts.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Extract Fonts: pulls embedded font programs out of the PDF into a ZIP.
class ExtractFontsView extends StatefulWidget {
  final File file;
  const ExtractFontsView({super.key, required this.file});

  @override
  State<ExtractFontsView> createState() => _ExtractFontsViewState();
}

class _ExtractFontsViewState extends State<ExtractFontsView>
    with ToolResultHandler, ToolViewMixin {
  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.EXTRACT_FONTS]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Fonts')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_FONTS] != c.httpStates[HttpStates.EXTRACT_FONTS],
        listenWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_FONTS] != c.httpStates[HttpStates.EXTRACT_FONTS],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.EXTRACT_FONTS],
          successMessage: 'Fonts extracted',
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.EXTRACT_FONTS]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.font_download_outlined, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Extract embedded fonts',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Embedded font programs are collected into a ZIP (.ttf / .otf / .pfb). '
                      'Fonts that are only referenced (not embedded) can\'t be extracted.',
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
                  label: const Text('Extract Fonts (ZIP)'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.EXTRACT_FONTS], label: 'Extracting fonts'),
          ]);
        },
      ),
    );
  }

  Future<void> _onExtract() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ExtractFontsEvent(
          extractFonts: ExtractFonts(file: file),
          cancelToken: cancelToken,
        ));
  }
}
