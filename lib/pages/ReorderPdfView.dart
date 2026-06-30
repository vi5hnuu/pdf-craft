import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class _Thumbnail {
  final bool isLoading;
  final String? error;
  final PdfPageImage? image;

  const _Thumbnail({this.isLoading = false, this.error, this.image});
}

class ReorderPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  const ReorderPdfView({super.key, required this.file, this.outFileName});

  @override
  State<ReorderPdfView> createState() => _ReorderPdfViewState();
}

class _ReorderPdfViewState extends State<ReorderPdfView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, _Thumbnail> _thumbnails = {};

  PdfDocument? _document;
  bool _docError = false;
  List<int> _pageIndexes = [];

  static const int _pageSize = 10;

  final TextEditingController _outFileNameC = TextEditingController();

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _scrollController.addListener(_onScroll);
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      if (!mounted) return;
      setState(() {
        _document = doc;
        _pageIndexes = List.generate(doc.pagesCount, (i) => i);
      });
      _loadNextBatch();
    } catch (_) {
      if (mounted) setState(() => _docError = true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (max > 0 && cur / max >= 0.9) _loadNextBatch();
  }

  Future<void> _loadNextBatch() async {
    if (_document == null) return;
    final loadingCount = _thumbnails.values.where((t) => t.isLoading).length;
    if (loadingCount > _pageSize * 0.8) return;

    // Retry errored thumbnails first
    for (final entry in _thumbnails.entries.where((e) => e.value.error != null).toList()) {
      await _loadThumbnail(entry.key);
    }

    final start = _thumbnails.length;
    for (var i = start; i < start + _pageSize && i < _document!.pagesCount; i++) {
      await _loadThumbnail(i + 1); // 1-based page numbers
    }
  }

  Future<void> _loadThumbnail(int pageNo) async {
    if (_thumbnails[pageNo]?.image != null || _thumbnails[pageNo]?.isLoading == true) return;
    if (!mounted) return;
    setState(() => _thumbnails[pageNo] = const _Thumbnail(isLoading: true));
    try {
      final page = await _document!.getPage(pageNo);
      final image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      if (!mounted) return;
      if (image == null) throw Exception();
      setState(() => _thumbnails[pageNo] = _Thumbnail(image: image));
    } catch (_) {
      if (mounted) setState(() => _thumbnails[pageNo] = const _Thumbnail(error: 'failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final md = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reorder PDF Pages'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        listenWhen: (p, c) => p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        buildWhen: (p, c) => p.httpStates[HttpStates.REORDER_PDF] != c.httpStates[HttpStates.REORDER_PDF],
        listener: (context, state) {
          final httpState = state.httpStates[HttpStates.REORDER_PDF];
          if (httpState?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Reorder successful', color: Colors.green);
            if (httpState?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': (httpState!.extras!['savedFile'] as File).path},
              );
            }
          } else if (httpState?.error != null) {
            NotificationService.showSnackbar(text: httpState!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Output File Name',
                        border: OutlineInputBorder(),
                      ),
                      controller: _outFileNameC,
                    ),
                  ),
                  Expanded(
                    child: _buildBody(theme, md),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      border: Border(top: BorderSide(color: theme.dividerColor)),
                    ),
                    child: FilledButton(
                      onPressed: _document != null ? _onReorderPages : null,
                      child: const Text('Reorder PDF Pages'),
                    ),
                  ),
                ],
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.REORDER_PDF], label: 'Saving new order'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme, MediaQueryData md) {
    if (_docError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Failed to load PDF', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_document == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final thumbnailWidth = md.size.width * 0.25;
    final thumbnailHeight = thumbnailWidth * 1.404;

    return ReorderableListView.builder(
      scrollController: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      onReorder: _reorder,
      itemCount: _thumbnails.length,
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: RichText(
          text: TextSpan(
            text: 'Reorder Pages ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            children: [
              TextSpan(
                text: ' (long press to drag)',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (context, index) {
        final pageNo = _pageIndexes[index] + 1;
        final thumbnail = _thumbnails[pageNo];

        return Padding(
          key: ValueKey('page-$pageNo'),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: thumbnailHeight,
                width: thumbnailWidth,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: thumbnail == null || thumbnail.isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : thumbnail.error != null
                        ? const Center(child: Icon(Icons.broken_image_outlined))
                        : thumbnail.image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.memory(thumbnail.image!.bytes, fit: BoxFit.fitWidth),
                              )
                            : const SizedBox.shrink(),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Utility.fileName(file: widget.file),
                        maxLines: 3,
                        style: const TextStyle(
                          overflow: TextOverflow.ellipsis,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Page $pageNo',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final removed = _pageIndexes.removeAt(oldIndex);
      _pageIndexes.insert(newIndex, removed);
    });
  }

  Future<void> _onReorderPages() async {
    BlocProvider.of<PdfBloc>(context).add(ReorderPdfEvent(
      reorderPdf: ReorderPdf(
        out_file_name: _outFileNameC.text.isEmpty ? 'reordered_file' : _outFileNameC.text,
        order: _pageIndexes,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _document?.close();
    _outFileNameC.dispose();
    super.dispose();
  }
}
