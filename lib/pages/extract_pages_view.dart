import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/reorder_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/page_selector_grid.dart';
import 'package:pdf_craft/widgets/pdf_page_thumbnail.dart';
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
    resetToolState([HttpStates.reorderPdf]);
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
        title: Text(ToolStrings.name(context, 'extract-pages')),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(onPressed: () => setState(_selected.clear), child: Text(L10n.of(context).clear)),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.reorderPdf] != c.httpStates[HttpStates.reorderPdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.reorderPdf] != c.httpStates[HttpStates.reorderPdf],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.reorderPdf], successMessage: L10n.of(context).pagesExtracted),
        builder: (context, state) {
          if (_doc == null) return const Center(child: CircularProgressIndicator());
          final loading = state.httpStates[HttpStates.reorderPdf]?.loading == true;
          return Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(L10n.of(context).selectPagesToKeep,
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
                  label: Text(_selected.isEmpty ? L10n.of(context).selectPagesToExtract : L10n.of(context).extractNPages(_selected.length)),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.reorderPdf], label: L10n.of(context).procWorking),
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
          reorderPdf: ReorderPdf(outFileName: 'extracted_pages', order: order, file: file),
          cancelToken: cancelToken,
        ));
  }
}
