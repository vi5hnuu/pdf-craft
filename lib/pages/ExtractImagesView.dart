import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/extract-images.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Extract Images: pulls every embedded raster image out of the PDF and returns
/// them as a ZIP of PNGs, which is opened in the device's default handler.
class ExtractImagesView extends StatefulWidget {
  final File file;
  const ExtractImagesView({super.key, required this.file});

  @override
  State<ExtractImagesView> createState() => _ExtractImagesViewState();
}

class _ExtractImagesViewState extends State<ExtractImagesView>
    with ToolResultHandler, ToolViewMixin {
  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.EXTRACT_IMAGES]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Images')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_IMAGES] != c.httpStates[HttpStates.EXTRACT_IMAGES],
        listenWhen: (p, c) => p.httpStates[HttpStates.EXTRACT_IMAGES] != c.httpStates[HttpStates.EXTRACT_IMAGES],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.EXTRACT_IMAGES],
          successMessage: 'Images extracted',
          // Result is a .zip — open it externally rather than the PDF viewer.
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.EXTRACT_IMAGES]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.collections_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Extract embedded images',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'All raster images found in this PDF are collected into a ZIP file (as PNGs). '
                        'Vector graphics and text are not included.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4),
                      ),
                    ],
                  ),
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
                  label: const Text('Extract Images (ZIP)'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.EXTRACT_IMAGES], label: 'Extracting images'),
          ]);
        },
      ),
    );
  }

  Future<void> _onExtract() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ExtractImagesEvent(
          extractImages: ExtractImages(file: file),
          cancelToken: cancelToken,
        ));
  }
}
