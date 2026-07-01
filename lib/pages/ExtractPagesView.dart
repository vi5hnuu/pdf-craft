import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/PageSelectorGrid.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

/// Extract Pages: pick the pages to keep and export a new PDF containing only
/// those, in page order. Reuses the reorder endpoint (order = kept pages).
class ExtractPagesView extends StatefulWidget {
  final File file;
  const ExtractPagesView({super.key, required this.file});

  @override
  State<ExtractPagesView> createState() => _ExtractPagesViewState();
}

class _ExtractPagesViewState extends State<ExtractPagesView>
    with ToolResultHandler, ToolViewMixin {
  PdfDocument? _doc;
  int _totalPages = 0;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.REORDER_PDF]);
    _open();
  }

  Future<void> _open() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      if (mounted) setState(() { _doc = doc; _totalPages = doc.pagesCount; });
    } catch (_) {}
  }

  @override
  void dispose() {
    final doc = _doc;
    if (doc != null) {
      PdfPageThumbnail.evictDocument(doc);
      doc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Pages'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(onPressed: () => setState(_selected.clear), child: const Text('Clear')),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.REORDER_PDF], successMessage: 'Pages extracted'),
        builder: (context, state) {
          if (_doc == null) return const Center(child: CircularProgressIndicator());
          final loading = state.httpStates[HttpStates.REORDER_PDF]?.loading == true;
          return Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Select the pages to keep.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
              Expanded(
                child: PageSelectorGrid(
                  document: _doc!,
                  totalPages: _totalPages,
                  selected: _selected,
                  accent: theme.colorScheme.primary,
                  onToggle: (i) => setState(() => _selected.contains(i) ? _selected.remove(i) : _selected.add(i)),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty || loading ? null : _onExtract,
                  icon: const Icon(Icons.content_cut),
                  label: Text(_selected.isEmpty ? 'Select pages to extract' : 'Extract ${_selected.length} page(s)'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.REORDER_PDF], label: 'Extracting pages'),
          ]);
        },
      ),
    );
  }

  Future<void> _onExtract() async {
    final order = _selected.toList()..sort();
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ReorderPdfEvent(
          reorderPdf: ReorderPdf(out_file_name: 'extracted_pages', order: order, file: file),
          cancelToken: cancelToken,
        ));
  }
}
