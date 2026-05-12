import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/RotatableItem.dart';
import 'package:pdfx/pdfx.dart';

class Thumbnail {
  bool? isLoading;
  String? error;
  PdfPageImage? image;

  Thumbnail({this.isLoading, this.error, this.image});
}

class RotatePdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  const RotatePdfView({super.key, required this.file, this.outFileName});

  @override
  State<RotatePdfView> createState() => _RotatePdfViewState();
}

class _RotatePdfViewState extends State<RotatePdfView> {
  late final PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  final Map<int, Thumbnail> _thumbnails = {};
  late final PdfDocument? document;
  late PdfController _pdfController;
  List<int> _pageIndexes = [];

  // Rotation state
  // Allowed PDF rotation angles (multiples of 90 per PDF spec)
  static const _allowedAngles = [0, 90, 180, 270];
  int _fileAngle = 90; // default: rotate all pages 90°
  // Per-page overrides: page number (1-based) → angle
  final Map<int, int> _pageAngles = {};
  // When true, page dimensions are kept unchanged (content rotates visually).
  // When false, width/height are swapped to match the new orientation.
  bool _swapDimensions = false;
  final TextEditingController _outFileNameC = TextEditingController();
  final TextEditingController _pageNoC = TextEditingController();
  int _selectedPageAngle = 90;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.file.path),
      initialPage: 1,
    );
    _pdfController.document.then((doc) {
      if (!mounted) return;
      setState(() {
        document = doc;
        _pageIndexes = List.generate(doc.pagesCount, (i) => i);
        _tryRenderingNextThumbnails();
      });
    });
    _scrollController.addListener(_tryRenderingNextThumbnails);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotate PDF Pages'),
        elevation: 2,
      ),
      body: FutureBuilder(
        future: _pdfController.document,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Icon(Icons.error, color: Colors.red, size: 48));
          }

          return BlocConsumer<PdfBloc, PdfState>(
            buildWhen: (prev, curr) =>
                prev.httpStates[HttpStates.ROTATE_PDF] != curr.httpStates[HttpStates.ROTATE_PDF],
            listenWhen: (prev, curr) =>
                prev.httpStates[HttpStates.ROTATE_PDF] != curr.httpStates[HttpStates.ROTATE_PDF],
            listener: (context, state) {
              final httpState = state.httpStates[HttpStates.ROTATE_PDF];
              if (httpState?.done == true) {
                AdsSingleton().dispatch(ShowInterstitialAd());
                NotificationService.showSnackbar(text: 'Rotated successfully', color: Colors.green);
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
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Output filename
                              TextFormField(
                                controller: _outFileNameC,
                                decoration: const InputDecoration(
                                  labelText: 'Output File Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // All-pages rotation angle
                              Text(
                                'Rotate All Pages',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select the angle to apply to all pages. Override individual pages below.',
                                style: theme.textTheme.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.6)),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: _allowedAngles.map((angle) {
                                  final selected = _fileAngle == angle;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(angle == 0 ? 'None' : '$angle°'),
                                      selected: selected,
                                      onSelected: (_) => setState(() => _fileAngle = angle),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // Dimension swap toggle
                              Card(
                                margin: EdgeInsets.zero,
                                child: SwitchListTile(
                                  title: const Text('Swap page dimensions'),
                                  subtitle: Text(
                                    _swapDimensions
                                        ? 'Width and height will be swapped to fit the rotated orientation.'
                                        : 'Page size stays unchanged; content rotates within the existing dimensions.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  value: _swapDimensions,
                                  onChanged: (v) => setState(() => _swapDimensions = v),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Per-page overrides
                              Text(
                                'Per-Page Overrides',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _pageNoC,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Page number',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      decoration: const InputDecoration(
                                        labelText: 'Angle',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: _selectedPageAngle,
                                      items: _allowedAngles
                                          .where((a) => a > 0)
                                          .map((a) => DropdownMenuItem(value: a, child: Text('$a°')))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedPageAngle = v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonal(
                                    onPressed: document == null
                                        ? null
                                        : () {
                                            final pNo = int.tryParse(_pageNoC.text);
                                            if (pNo == null || pNo < 1 || pNo > document!.pagesCount) {
                                              NotificationService.showSnackbar(
                                                  text: 'Invalid page number', color: Colors.red);
                                              return;
                                            }
                                            setState(() => _pageAngles.put(pNo, _selectedPageAngle));
                                            _pageNoC.clear();
                                          },
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_pageAngles.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _pageAngles.entries.map((e) {
                                    return Chip(
                                      label: Text('Page ${e.key}: ${e.value}°'),
                                      onDeleted: () => setState(() => _pageAngles.remove(e.key)),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 20),

                              // Thumbnail preview
                              Text(
                                'Page Preview',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Preview is approximate — actual output will not overlap pages.',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber.shade700),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                controller: _scrollController,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _thumbnails.length,
                                itemBuilder: (context, index) {
                                  final pageNo = _pageIndexes[index] + 1;
                                  final thumbnail = _thumbnails[pageNo];
                                  final thumbnailWidth = MediaQuery.of(context).size.width * 0.45;
                                  final thumbnailHeight = thumbnailWidth * 1.37;

                                  return Padding(
                                    key: ValueKey('page-$pageNo'),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: RotatablePageWidget(
                                        originalWidth: thumbnailWidth,
                                        originalHeight: thumbnailHeight,
                                        maintainAspectRatio: !_swapDimensions,
                                        rotationAngle: (_pageAngles[pageNo] ?? _fileAngle).toDouble(),
                                        child: Container(
                                          height: thumbnailHeight,
                                          width: thumbnailWidth,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            border: Border.all(color: theme.dividerColor),
                                          ),
                                          child: thumbnail?.isLoading == true
                                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                              : thumbnail?.error != null
                                                  ? const Center(child: Icon(Icons.broken_image_outlined))
                                                  : Image.memory(thumbnail!.image!.bytes, fit: BoxFit.contain),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          border: Border(top: BorderSide(color: theme.dividerColor)),
                        ),
                        child: FilledButton(
                          onPressed: _fileAngle == 0 && _pageAngles.isEmpty ? null : _onRotatePages,
                          child: const Text('Rotate PDF Pages'),
                        ),
                      ),
                    ],
                  ),

                  if (state.isLoading(forr: HttpStates.ROTATE_PDF))
                    Container(
                      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                      child: Center(child: SpinKitThreeBounce(color: primary, size: 45)),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _tryRenderingNextThumbnails() async {
    if (document == null) return;
    await _reloadErroredThumbnails(document!);
    if (_thumbnails.isEmpty) {
      await _loadThumbnails();
      return;
    }
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (max > 0 && (cur / max) * 100 < 90) return;
    await _loadThumbnails();
  }

  Future<void> _reloadErroredThumbnails(PdfDocument doc) async {
    for (final e in _thumbnails.entries.where((e) => e.value.error != null).toList()) {
      await _loadThumbnail(document: doc, pageNo: e.key);
    }
  }

  Future<void> _loadThumbnails() async {
    if (document == null) return;
    final loading = _thumbnails.values.where((t) => t.isLoading == true).length;
    if ((loading / _pageSize) * 100 > 80) return;
    final start = _thumbnails.length;
    for (var i = start; i < start + _pageSize && i < document!.pagesCount; i++) {
      await _loadThumbnail(document: document!, pageNo: i + 1);
    }
  }

  Future<void> _loadThumbnail({required PdfDocument document, required int pageNo}) async {
    if (_thumbnails[pageNo]?.image != null || _thumbnails[pageNo]?.isLoading == true) return;
    try {
      if (mounted) setState(() => _thumbnails.put(pageNo, Thumbnail(isLoading: true)));
      final page = await document.getPage(pageNo);
      final image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      if (image == null) throw Exception();
      if (mounted) setState(() => _thumbnails.put(pageNo, Thumbnail(image: image)));
    } catch (_) {
      if (mounted) setState(() => _thumbnails.put(pageNo, Thumbnail(error: 'failed')));
    }
  }

  Future<void> _onRotatePages() async {
    bloc.add(RotatePdfEvent(
      rotatePdf: RotatePdf(
        out_file_name: _outFileNameC.text.isEmpty ? 'rotated_file' : _outFileNameC.text,
        file_angle: _fileAngle,
        maintain_ratio: !_swapDimensions,
        page_angles: _pageAngles,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _scrollController.dispose();
    _outFileNameC.dispose();
    _pageNoC.dispose();
    super.dispose();
  }
}
