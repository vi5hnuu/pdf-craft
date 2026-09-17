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

/// Delete Pages: pick pages to remove and export the remainder — a faster,
/// single-purpose alternative to the full Organize tool. Reuses the reorder
/// endpoint (order = all pages except the selected ones).
class DeletePagesView extends StatefulWidget {
  final File file;
  const DeletePagesView({super.key, required this.file});

  @override
  State<DeletePagesView> createState() => _DeletePagesViewState();
}

class _DeletePagesViewState extends State<DeletePagesView>
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

  int get _remaining => _totalPages - _selected.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(ToolStrings.name(context, 'delete-pages')),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(onPressed: () => setState(_selected.clear), child: Text(L10n.of(context).clear)),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.reorderPdf] != c.httpStates[HttpStates.reorderPdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.reorderPdf] != c.httpStates[HttpStates.reorderPdf],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.reorderPdf], successMessage: L10n.of(context).pagesDeleted),
        builder: (context, state) {
          if (_doc == null) return const Center(child: CircularProgressIndicator());
          final loading = state.httpStates[HttpStates.reorderPdf]?.loading == true;
          final canDelete = _selected.isNotEmpty && _remaining >= 1;
          return Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(L10n.of(context).selectPagesToRemove,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
              Expanded(
                child: PageSelectorGrid(
                  document: _doc!,
                  totalPages: _totalPages,
                  selected: _selected,
                  accent: Colors.red,
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
                  onPressed: canDelete && !loading ? _onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(_selected.isEmpty
                      ? L10n.of(context).selectPagesToDelete
                      : _remaining < 1
                          ? L10n.of(context).keepAtLeastOnePage
                          : L10n.of(context).deletePagesAction(_selected.length, _remaining)),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.reorderPdf], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Future<void> _onDelete() async {
    final order = [for (int i = 0; i < _totalPages; i++) if (!_selected.contains(i)) i];
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ReorderPdfEvent(
          reorderPdf: ReorderPdf(outFileName: 'pages_removed', order: order, file: file),
          cancelToken: cancelToken,
        ));
  }
}
