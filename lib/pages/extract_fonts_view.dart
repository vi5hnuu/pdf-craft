import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/extract_fonts.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

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
    resetToolState([HttpStates.extractFonts]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'extract-fonts'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.extractFonts] != c.httpStates[HttpStates.extractFonts],
        listenWhen: (p, c) => p.httpStates[HttpStates.extractFonts] != c.httpStates[HttpStates.extractFonts],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.extractFonts],
          successMessage: L10n.of(context).fontsExtracted,
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.extractFonts]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.font_download_outlined, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(L10n.of(context).extractEmbeddedFonts,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      L10n.of(context).extractFontsHint,
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
                  label: Text(L10n.of(context).extractFontsZip),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.extractFonts], label: L10n.of(context).procWorking),
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
