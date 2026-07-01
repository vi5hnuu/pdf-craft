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
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

/// Visual page organiser: drag to reorder and tap ✕ to delete pages on a single
/// thumbnail list, then export. Commits via the existing reorder endpoint, whose
/// `order` (0-indexed page list) naturally expresses both reorder and deletion
/// (omitted pages are dropped).
class OrganizePagesView extends StatefulWidget {
  final File file;
  const OrganizePagesView({super.key, required this.file});

  @override
  State<OrganizePagesView> createState() => _OrganizePagesViewState();
}

class _OrganizePagesViewState extends State<OrganizePagesView>
    with ToolResultHandler, ToolViewMixin {
  PdfDocument? _doc;
  bool _loadError = false;

  /// Current arrangement as original 0-indexed page numbers. Deleting removes an
  /// entry; reordering permutes it. This list is exactly the reorder `order`.
  List<int> _order = [];
  int _totalPages = 0;

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
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _totalPages = doc.pagesCount;
        _order = List.generate(doc.pagesCount, (i) => i);
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  void _deleteAt(int i) {
    if (_order.length <= 1) {
      NotificationService.showSnackbar(text: 'A PDF needs at least one page', color: Colors.orange);
      return;
    }
    setState(() => _order.removeAt(i));
  }

  void _reset() => setState(() => _order = List.generate(_totalPages, (i) => i));

  Future<void> _onSave() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ReorderPdfEvent(
          reorderPdf: ReorderPdf(
            out_file_name: 'organized_file',
            order: List<int>.from(_order),
            file: file,
          ),
          cancelToken: cancelToken,
        ));
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
    final removed = _totalPages - _order.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organize Pages'),
        actions: [
          if (_order.length != _totalPages)
            TextButton(
              onPressed: _reset,
              child: Text('Reset', style: TextStyle(color: theme.colorScheme.primary)),
            ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.REORDER_PDF], successMessage: 'Pages organized'),
        builder: (context, state) {
          if (_loadError) {
            return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40));
          }
          if (_doc == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(children: [
            Column(children: [
              if (removed > 0)
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Text('$removed page${removed == 1 ? '' : 's'} will be removed · ${_order.length} kept',
                      style: theme.textTheme.bodySmall),
                ),
              Expanded(child: _buildList(theme)),
              _buildSaveBar(theme, state.httpStates[HttpStates.REORDER_PDF]?.loading == true),
            ]),
            processingOverlay(state.httpStates[HttpStates.REORDER_PDF], label: 'Saving organized PDF'),
          ]);
        },
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _order.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _order.removeAt(oldIndex);
          _order.insert(newIndex, item);
        });
      },
      itemBuilder: (context, i) {
        final original = _order[i];
        return Padding(
          key: ValueKey('page_$original'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                // Thumbnail (cached after first render).
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 54,
                    height: 72,
                    color: theme.colorScheme.surfaceContainerHighest,
                    // Cached widget keyed by page — never re-renders on drag/delete.
                    child: PdfPageThumbnail(
                      key: ValueKey('thumb_$original'),
                      document: _doc!,
                      pageNumber: original + 1,
                      width: 54,
                      height: 72,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Page ${original + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove page',
                  onPressed: () => _deleteAt(i),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveBar(ThemeData theme, bool loading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: FilledButton.icon(
        onPressed: loading ? null : _onSave,
        icon: const Icon(Icons.save_alt),
        label: const Text('Export PDF'),
      ),
    );
  }
}
