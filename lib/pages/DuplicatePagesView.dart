import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/duplicate-pages.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

class DuplicatePagesView extends StatefulWidget {
  final File file;
  const DuplicatePagesView({super.key, required this.file});

  @override
  State<DuplicatePagesView> createState() => _DuplicatePagesViewState();
}

class _DuplicatePagesViewState extends State<DuplicatePagesView> {
  PdfDocument? _doc;
  int _totalPages = 0;
  // 0-indexed page -> copies to insert. A page is "selected" when it has an entry.
  final Map<int, int> _pageCounts = {};
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _openDocument();
  }

  Future<void> _openDocument() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      if (mounted) setState(() { _doc = doc; _totalPages = doc.pagesCount; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Pages'),
        actions: [
          if (_pageCounts.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _pageCounts.clear()),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.DUPLICATE_PAGES] != c.httpStates[HttpStates.DUPLICATE_PAGES],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.DUPLICATE_PAGES] != c.httpStates[HttpStates.DUPLICATE_PAGES],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.DUPLICATE_PAGES];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Pages duplicated', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path},
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.DUPLICATE_PAGES]?.loading == true;
          return Stack(children: [
            Column(children: [
              // Instruction
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Tap a page to select it, then set how many copies of that page to add.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),

              // Page thumbnail grid
              Expanded(
                child: _doc == null
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: _totalPages,
                        itemBuilder: (context, i) => _buildPageTile(i),
                      ),
              ),

              // Count stepper + submit
              _buildBottomBar(theme, loading),
            ]),
            LoadingOverlay(
              httpState: state.httpStates[HttpStates.DUPLICATE_PAGES],
              label: 'Duplicating pages',
              onCancel: () => _cancelToken?.cancel('cancelled-by-user'),
            ),
          ]);
        },
      ),
    );
  }

  Widget _buildPageTile(int i) {
    final selected = _pageCounts.containsKey(i);
    final count = _pageCounts[i] ?? 1;
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _pageCounts.remove(i);
        } else {
          _pageCounts[i] = 1;
        }
      }),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: PdfPageThumbnail(
            document: _doc!,
            pageNumber: i + 1,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Selection overlay with a per-page copy stepper.
        if (selected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _stepBtn(Icons.remove, count > 1
                        ? () => setState(() => _pageCounts[i] = count - 1)
                        : null),
                    Text('×$count',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    _stepBtn(Icons.add, count < 20
                        ? () => setState(() => _pageCounts[i] = count + 1)
                        : null),
                  ]),
                ),
              ),
            ),
          ),
        // Page number label
        Positioned(
          bottom: 4, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: onTap == null ? Colors.white38 : Colors.white),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool loading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _pageCounts.isEmpty || loading ? null : _onDuplicate,
            icon: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.copy_all),
            label: Text(_pageCounts.isEmpty
                ? 'Select pages to duplicate'
                : 'Add $_totalCopies cop${_totalCopies == 1 ? 'y' : 'ies'} across ${_pageCounts.length} page(s)'),
          ),
        ),
      ]),
    );
  }

  int get _totalCopies => _pageCounts.values.fold(0, (a, b) => a + b);

  Future<void> _onDuplicate() async {
    _cancelToken = CancelToken();
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    BlocProvider.of<PdfBloc>(context).add(DuplicatePagesEvent(
      duplicatePages: DuplicatePages(
        pageCounts: Map<int, int>.from(_pageCounts),
        file: file,
      ),
      cancelToken: _cancelToken,
    ));
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }
}
