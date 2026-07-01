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
import 'package:pdfx/pdfx.dart';

/// Reverse Page Order: flips the page sequence (last page first). Reuses the
/// reorder endpoint with a reversed order list — no dedicated backend needed.
class ReversePagesView extends StatefulWidget {
  final File file;
  const ReversePagesView({super.key, required this.file});

  @override
  State<ReversePagesView> createState() => _ReversePagesViewState();
}

class _ReversePagesViewState extends State<ReversePagesView>
    with ToolResultHandler, ToolViewMixin {
  int? _totalPages;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.REORDER_PDF]);
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      if (mounted) setState(() => _totalPages = doc.pagesCount);
      await doc.close();
    } catch (_) {
      if (mounted) setState(() => _totalPages = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reverse Page Order')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.REORDER_PDF], successMessage: 'Page order reversed'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.REORDER_PDF]?.loading == true;
          final pages = _totalPages;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_vert, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Reverse the page order',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        pages == null
                            ? 'Reading document…'
                            : 'The last page becomes the first. This document has $pages page${pages == 1 ? '' : 's'}.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                  onPressed: (pages != null && pages > 1 && !loading) ? _onReverse : null,
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Reverse & Save'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.REORDER_PDF], label: 'Reversing pages'),
          ]);
        },
      ),
    );
  }

  Future<void> _onReverse() async {
    final n = _totalPages ?? 0;
    final order = [for (int i = n - 1; i >= 0; i--) i];
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ReorderPdfEvent(
          reorderPdf: ReorderPdf(out_file_name: 'reversed_pages', order: order, file: file),
          cancelToken: cancelToken,
        ));
  }
}
