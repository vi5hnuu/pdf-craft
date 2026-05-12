import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdf_craft/widgets/RotatableItem.dart';
import 'package:pdfx/pdfx.dart';

class _Thumbnail {
  bool isLoading;
  String? error;
  PdfPageImage? image;
  _Thumbnail({this.isLoading = false, this.error, this.image});
}

class RotatePdfView extends StatefulWidget {
  final File file;
  const RotatePdfView({super.key, required this.file});

  @override
  State<RotatePdfView> createState() => _RotatePdfViewState();
}

class _RotatePdfViewState extends State<RotatePdfView> {
  late PdfController _pdfController;
  PdfDocument? _document;

  final ScrollController _scroll = ScrollController();
  final Map<int, _Thumbnail> _thumbnails = {};
  List<int> _pageIndexes = [];

  static const _angles = [0, 90, 180, 270];
  int _fileAngle = 0;
  // Keys are 1-indexed (user-facing); converted to 0-indexed before sending to backend
  final Map<int, int> _pageAngles = {};
  bool _maintainRatio = true;

  final _outFileNameC = TextEditingController();
  final _pageNoC = TextEditingController();
  int _selectedPageAngle = 90;

  static const _pageSize = 10;

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
        _document = doc;
        _pageIndexes = List.generate(doc.pagesCount, (i) => i);
      });
      _loadNextBatch();
    });
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final cur = _scroll.position.pixels;
    if (max > 0 && cur / max >= 0.9) _loadNextBatch();
  }

  Future<void> _loadNextBatch() async {
    if (_document == null) return;
    final loading = _thumbnails.values.where((t) => t.isLoading).length;
    if (loading > _pageSize * 0.8) return;

    final start = _thumbnails.length;
    for (var i = start; i < start + _pageSize && i < _document!.pagesCount; i++) {
      await _loadThumbnail(i + 1);
    }
    for (final e in _thumbnails.entries.where((e) => e.value.error != null).toList()) {
      await _loadThumbnail(e.key);
    }
  }

  Future<void> _loadThumbnail(int pageNo) async {
    if (_thumbnails[pageNo]?.image != null || _thumbnails[pageNo]?.isLoading == true) return;
    if (!mounted) return;
    setState(() => _thumbnails[pageNo] = _Thumbnail(isLoading: true));
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
      if (mounted) setState(() => _thumbnails[pageNo] = _Thumbnail(error: 'failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rotate PDF Pages')),
      body: FutureBuilder(
        future: _pdfController.document,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 48));
          }
          return BlocConsumer<PdfBloc, PdfState>(
            buildWhen: (p, c) =>
                p.httpStates[HttpStates.ROTATE_PDF] != c.httpStates[HttpStates.ROTATE_PDF],
            listenWhen: (p, c) =>
                p.httpStates[HttpStates.ROTATE_PDF] != c.httpStates[HttpStates.ROTATE_PDF],
            listener: (context, state) {
              final s = state.httpStates[HttpStates.ROTATE_PDF];
              if (s?.done == true) {
                AdsSingleton().dispatch(ShowInterstitialAd());
                NotificationService.showSnackbar(text: 'Rotated successfully', color: Colors.green);
                if (s?.extras?['savedFile'] is File) {
                  GoRouter.of(context).pushNamed(
                    AppRoutes.pdfFilePreviewRoute.name,
                    pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path},
                  );
                }
              } else if (s?.loading == true) {
                NotificationService.showSnackbar(text: 'Rotating PDF…', color: Colors.blue);
              } else if (s?.error != null) {
                NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
              }
            },
            builder: (context, state) {
              return Stack(children: [
                Column(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Output file name
                          TextFormField(
                            controller: _outFileNameC,
                            decoration: const InputDecoration(
                              labelText: 'Output File Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // All-pages angle
                          Text('Rotate All Pages',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Applies to every page. Override specific pages below.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: _angles.map((angle) => ChoiceChip(
                              label: Text(angle == 0 ? 'None' : '$angle°'),
                              selected: _fileAngle == angle,
                              onSelected: (_) => setState(() => _fileAngle = angle),
                            )).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Maintain ratio toggle
                          Card(
                            margin: EdgeInsets.zero,
                            child: SwitchListTile(
                              title: const Text('Swap page dimensions'),
                              subtitle: Text(
                                _maintainRatio
                                    ? 'Width and height swap to match the rotated orientation.'
                                    : 'Page size unchanged; content rotates within existing dimensions.',
                                style: theme.textTheme.bodySmall,
                              ),
                              value: _maintainRatio,
                              onChanged: (v) => setState(() => _maintainRatio = v),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Per-page overrides
                          Text('Per-Page Overrides',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(children: [
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
                                initialValue: _selectedPageAngle,
                                items: _angles
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
                              onPressed: _addPageAngle,
                              child: const Text('Add'),
                            ),
                          ]),
                          if (_pageAngles.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _pageAngles.entries.map((e) => Chip(
                                label: Text('Page ${e.key}: ${e.value}°'),
                                onDeleted: () => setState(() => _pageAngles.remove(e.key)),
                              )).toList(),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Page thumbnails
                          Text('Page Preview',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Preview is approximate — actual output may differ.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.amber.shade700),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_thumbnails.length, (index) {
                            final pageNo = _pageIndexes[index] + 1;
                            final thumb = _thumbnails[pageNo];
                            final w = MediaQuery.of(context).size.width * 0.45;
                            final h = w * 1.37;
                            return Padding(
                              key: ValueKey('page-$pageNo'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: RotatablePageWidget(
                                  originalWidth: w,
                                  originalHeight: h,
                                  maintainAspectRatio: _maintainRatio,
                                  rotationAngle: (_pageAngles[pageNo] ?? _fileAngle).toDouble(),
                                  child: Container(
                                    width: w,
                                    height: h,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      border: Border.all(color: theme.dividerColor),
                                    ),
                                    child: thumb?.isLoading == true
                                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                        : thumb?.error != null
                                            ? const Center(child: Icon(Icons.broken_image_outlined))
                                            : thumb?.image != null
                                                ? Image.memory(thumb!.image!.bytes, fit: BoxFit.contain)
                                                : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Submit bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      border: Border(top: BorderSide(color: theme.dividerColor)),
                    ),
                    child: FilledButton(
                      onPressed: (_fileAngle == 0 && _pageAngles.isEmpty) ? null : _onSubmit,
                      child: const Text('Rotate PDF Pages'),
                    ),
                  ),
                ]),
                LoadingOverlay(httpState: state.httpStates[HttpStates.ROTATE_PDF]),
              ]);
            },
          );
        },
      ),
    );
  }

  void _addPageAngle() {
    if (_document == null) return;
    final pNo = int.tryParse(_pageNoC.text);
    if (pNo == null || pNo < 1 || pNo > _document!.pagesCount) {
      NotificationService.showSnackbar(text: 'Invalid page number', color: Colors.red);
      return;
    }
    setState(() => _pageAngles.put(pNo, _selectedPageAngle));
    _pageNoC.clear();
  }

  Future<void> _onSubmit() async {
    // Convert 1-indexed user page numbers to 0-indexed for backend
    final zeroIndexedPageAngles = Map.fromEntries(
      _pageAngles.entries.map((e) => MapEntry(e.key - 1, e.value)),
    );
    BlocProvider.of<PdfBloc>(context).add(RotatePdfEvent(
      rotatePdf: RotatePdf(
        out_file_name: _outFileNameC.text.trim().isEmpty ? 'rotated_file' : _outFileNameC.text.trim(),
        file_angle: _fileAngle,
        maintain_ratio: _maintainRatio,
        page_angles: zeroIndexedPageAngles,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _pdfController.dispose();
    _outFileNameC.dispose();
    _pageNoC.dispose();
    super.dispose();
  }
}
