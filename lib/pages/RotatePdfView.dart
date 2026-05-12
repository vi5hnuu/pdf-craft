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

class _Thumb {
  bool isLoading;
  String? error;
  PdfPageImage? image;
  _Thumb({this.isLoading = false, this.error, this.image});
}

class RotatePdfView extends StatefulWidget {
  final File file;
  final String? outFileName;
  const RotatePdfView({super.key, required this.file, this.outFileName});

  @override
  State<RotatePdfView> createState() => _RotatePdfViewState();
}

class _RotatePdfViewState extends State<RotatePdfView> {
  // same pattern as original: PdfController + FutureBuilder
  late PdfController _pdfController;
  PdfDocument? _document;

  final ScrollController _scroll = ScrollController();
  final Map<int, _Thumb> _thumbnails = {};
  List<int> _pageIndexes = [];

  // Valid PDF rotation angles per spec
  static const _angles = [0, 90, 180, 270];
  int _fileAngle = 0;
  // Keys are 1-indexed (user-facing); subtract 1 before sending to backend
  final Map<int, int> _pageAngles = {};
  bool _maintainRatio = true;

  final TextEditingController _outFileNameC = TextEditingController();
  final TextEditingController _pageNoC = TextEditingController();
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
        _loadNextBatch();
      });
    });
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max > 0 && _scroll.position.pixels / max >= 0.9) _loadNextBatch();
  }

  void _loadNextBatch() {
    if (_document == null) return;
    final loading = _thumbnails.values.where((t) => t.isLoading).length;
    if ((loading / _pageSize) * 100 > 80) return;

    final start = _thumbnails.length;
    for (var i = start; i < start + _pageSize && i < _document!.pagesCount; i++) {
      _loadThumbnail(i + 1);
    }
    for (final e in _thumbnails.entries.where((e) => e.value.error != null).toList()) {
      _loadThumbnail(e.key);
    }
  }

  Future<void> _loadThumbnail(int pageNo) async {
    if (_thumbnails[pageNo]?.image != null || _thumbnails[pageNo]?.isLoading == true) return;
    setState(() => _thumbnails.put(pageNo, _Thumb(isLoading: true)));
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
      setState(() => _thumbnails.put(pageNo, _Thumb(image: image)));
    } catch (_) {
      if (mounted) setState(() => _thumbnails.put(pageNo, _Thumb(error: 'failed')));
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
                NotificationService.showSnackbar(text: 'Rotating…', color: Colors.blue);
              } else if (s?.error != null) {
                NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
              }
            },
            builder: (context, state) {
              // Identical structure to original: fixed form at top, Expanded ListView for thumbnails
              return Stack(children: [
                Column(children: [
                  // ── Form area ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: TextFormField(
                      controller: _outFileNameC,
                      decoration: const InputDecoration(
                        labelText: 'Output File Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  // All-pages angle chips
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Pages Angle',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: _angles.map((a) => ChoiceChip(
                            label: Text(a == 0 ? 'None' : '$a°'),
                            selected: _fileAngle == a,
                            onSelected: (_) => setState(() => _fileAngle = a),
                          )).toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Applies to all pages unless overridden per-page below.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),

                  // Maintain ratio toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Swap page dimensions'),
                      subtitle: Text(
                        _maintainRatio
                            ? 'Width and height swap to fit the rotated content.'
                            : 'Page size stays the same; content rotates within it.',
                        style: theme.textTheme.bodySmall,
                      ),
                      value: _maintainRatio,
                      onChanged: (v) => setState(() => _maintainRatio = v),
                    ),
                  ),

                  // Per-page overrides
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pageNoC,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Page No.',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedPageAngle,
                              decoration: const InputDecoration(
                                labelText: 'Angle',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
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
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _pageAngles.entries.map((e) => Chip(
                              label: Text('p${e.key}: ${e.value}°',
                                  style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setState(() => _pageAngles.remove(e.key)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'Preview is approximate — actual PDF may differ.',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),

                  // ── Thumbnail list (identical to original: Expanded + ListView.builder) ──
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _thumbnails.length,
                      itemBuilder: (context, index) {
                        final pageNo = _pageIndexes[index] + 1;
                        final thumb = _thumbnails[pageNo];
                        final w = MediaQuery.of(context).size.width * 0.45;
                        final h = w * 1.37;
                        return Padding(
                          key: ValueKey('page-$pageNo'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      },
                    ),
                  ),

                  // ── Submit bar ───────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
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
    // Convert 1-indexed user page numbers → 0-indexed for backend
    final zeroIndexed = Map.fromEntries(
      _pageAngles.entries.map((e) => MapEntry(e.key - 1, e.value)),
    );
    BlocProvider.of<PdfBloc>(context).add(RotatePdfEvent(
      rotatePdf: RotatePdf(
        out_file_name: _outFileNameC.text.trim().isEmpty ? 'rotated_file' : _outFileNameC.text.trim(),
        file_angle: _fileAngle,
        maintain_ratio: _maintainRatio,
        page_angles: zeroIndexed,
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
