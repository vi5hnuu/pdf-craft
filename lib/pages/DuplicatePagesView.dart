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
  final Set<int> _selectedPages = {}; // 0-indexed
  int _count = 1; // copies to insert

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
          if (_selectedPages.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selectedPages.clear()),
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
                  'Tap pages to select them for duplication.',
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
            LoadingOverlay(httpState: state.httpStates[HttpStates.DUPLICATE_PAGES], label: 'Duplicating pages'),
          ]);
        },
      ),
    );
  }

  Widget _buildPageTile(int i) {
    final selected = _selectedPages.contains(i);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) _selectedPages.remove(i); else _selectedPages.add(i);
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
        // Selection overlay
        if (selected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.check_circle, color: Colors.white, size: 32),
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

  Widget _buildBottomBar(ThemeData theme, bool loading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Count stepper
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Copies:'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _count > 1 ? () => setState(() => _count--) : null,
          ),
          Text('$_count', style: theme.textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _count < 10 ? () => setState(() => _count++) : null,
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selectedPages.isEmpty || loading ? null : _onDuplicate,
            icon: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.copy_all),
            label: Text(_selectedPages.isEmpty
                ? 'Select pages to duplicate'
                : 'Duplicate ${_selectedPages.length} page(s) × $_count'),
          ),
        ),
      ]),
    );
  }

  Future<void> _onDuplicate() async {
    BlocProvider.of<PdfBloc>(context).add(DuplicatePagesEvent(
      duplicatePages: DuplicatePages(
        pages: _selectedPages.toList()..sort(),
        count: _count,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }
}
