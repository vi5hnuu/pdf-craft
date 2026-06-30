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
  final TextEditingController pageNoC = TextEditingController();
  final TextEditingController pageAngleC = TextEditingController();
  final TextEditingController outFileNameC = TextEditingController();
  // Separate controller for all-page angle text field
  final TextEditingController fileAngleC = TextEditingController(text: '0');
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);

  final int pageSize = 10;
  final ScrollController controller = ScrollController();
  final Map<int, Thumbnail> thumbnails = {};

  PdfDocument? document;
  late PdfController _pdfController;
  List<int> _pageIndexes = [];

  int file_angle = 0;
  // Keys are 1-indexed (user-facing); converted to 0-indexed on submit
  Map<int, int> page_angles = {};
  bool maintain_ratio = true;

  // Quick-preset angles shown as chips below the all-page angle field
  static const _presets = [0, 90, 180, 270];

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.file.path),
      initialPage: 1,
    );
    _pdfController.document.then((doc) {
      if (!mounted) return;
      setState(() {
        document = doc;
        _pageIndexes = List.generate(doc.pagesCount, (index) => index);
      });
      _tryRenderingNextThumbnails();
    });
    controller.addListener(() => _tryRenderingNextThumbnails());
    fileAngleC.addListener(() {
      final v = int.tryParse(fileAngleC.text) ?? 0;
      if (v != file_angle) setState(() => file_angle = v);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final md = MediaQuery.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Rotate PDF Pages')),
      body: FutureBuilder(
        future: _pdfController.document,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Icon(Icons.error, color: Colors.red));
          }
          return BlocConsumer<PdfBloc, PdfState>(
            buildWhen: (previous, current) =>
                previous.httpStates[HttpStates.ROTATE_PDF] !=
                current.httpStates[HttpStates.ROTATE_PDF],
            listenWhen: (previous, current) =>
                previous.httpStates[HttpStates.ROTATE_PDF] !=
                current.httpStates[HttpStates.ROTATE_PDF],
            listener: (context, state) {
              final httpState = state.httpStates[HttpStates.ROTATE_PDF];
              if (httpState?.done == true) {
                AdsSingleton().dispatch(ShowInterstitialAd());
                NotificationService.showSnackbar(
                    text: 'Rotate Successful', color: Colors.green);
                if (httpState?.extras?['savedFile'] is File) {
                  GoRouter.of(context).pushNamed(
                    AppRoutes.pdfFilePreviewRoute.name,
                    pathParameters: {
                      'pdfFilePath':
                          (httpState!.extras!['savedFile'] as File).path
                    },
                  );
                }
              } else if (httpState?.error != null) {
                NotificationService.showSnackbar(
                    text: httpState!.error!, color: Colors.red);
              }
            },
            builder: (context, state) {
              return Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // ── Scrollable form area ──────────────────────────
                      Expanded(
                        child: ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          children: [
                            // Output file name
                            TextFormField(
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                labelText: 'Output File Name',
                                border: OutlineInputBorder(),
                              ),
                              controller: outFileNameC,
                            ),
                            const SizedBox(height: 16),

                            // ── All-pages angle ────────────────────────
                            Text('All Pages Angle',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: fileAngleC,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Angle (any value, e.g. 45, 90, 270)',
                                border: OutlineInputBorder(),
                                suffixText: '°',
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Quick-preset chips — tap to fill the field
                            Wrap(
                              spacing: 6,
                              children: _presets.map((a) {
                                final selected = file_angle == a;
                                return ActionChip(
                                  label: Text(a == 0 ? 'None (0°)' : '$a°'),
                                  backgroundColor: selected
                                      ? primary.withValues(alpha: 0.18)
                                      : null,
                                  side: selected
                                      ? BorderSide(color: primary)
                                      : null,
                                  onPressed: () {
                                    fileAngleC.text = '$a';
                                    setState(() => file_angle = a);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All pages will rotate at this angle. Override per page below.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55)),
                            ),
                            const SizedBox(height: 16),

                            // ── Maintain aspect ratio ──────────────────
                            Card(
                              margin: EdgeInsets.zero,
                              child: SwitchListTile(
                                dense: true,
                                title: const Text('Maintain Aspect Ratio'),
                                subtitle: Text(
                                  maintain_ratio
                                      ? 'Width and height swap to fit rotated content.'
                                      : 'Page size stays the same; content rotates within it.',
                                  style: theme.textTheme.bodySmall,
                                ),
                                value: maintain_ratio,
                                onChanged: (v) =>
                                    setState(() => maintain_ratio = v),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Preview is approximate — actual PDF may differ.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.amber),
                            ),
                            const SizedBox(height: 16),

                            // ── Per-page angle override ────────────────
                            Text('Per-Page Angle Override',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      label: Text('Page No.'),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    controller: pageNoC,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      label: Text('Angle'),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      suffixText: '°',
                                    ),
                                    controller: pageAngleC,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: document == null ? null : _addPageAngle,
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                            if (page_angles.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: page_angles.entries.map((entry) {
                                  return Chip(
                                    label: Text(
                                        'p${entry.key}: ${entry.value}°',
                                        style: const TextStyle(fontSize: 12)),
                                    onDeleted: () => setState(
                                        () => page_angles.remove(entry.key)),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // ── Thumbnail previews ─────────────────────
                            if (thumbnails.isNotEmpty)
                              Text('Preview',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ...List.generate(thumbnails.length, (index) {
                              final pNo = _pageIndexes[index] + 1;
                              final thumbnail = thumbnails[pNo];
                              final thumbW = md.size.width * 0.42;
                              final thumbH = thumbW * 1.37;
                              return Padding(
                                key: ValueKey('page-$pNo'),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Center(
                                  child: RotatablePageWidget(
                                    originalWidth: thumbW,
                                    originalHeight: thumbH,
                                    maintainAspectRatio: maintain_ratio,
                                    rotationAngle:
                                        (page_angles[pNo] ?? file_angle)
                                            .toDouble(),
                                    child: Container(
                                      height: thumbH,
                                      width: thumbW,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        border: Border.all(
                                            color: theme.dividerColor),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: thumbnail?.isLoading == true
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2))
                                          : thumbnail?.error != null
                                              ? const Center(
                                                  child: Icon(
                                                      Icons.broken_image_outlined))
                                              : thumbnail?.image != null
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(3),
                                                      child: Image.memory(
                                                          thumbnail!.image!.bytes,
                                                          fit: BoxFit.contain))
                                                  : const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (thumbnails.length < (document?.pagesCount ?? 0))
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                          ],
                        ),
                      ),

                      // ── Submit bar ────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          border:
                              Border(top: BorderSide(color: theme.dividerColor)),
                        ),
                        child: FilledButton(
                          onPressed:
                              file_angle == 0 && page_angles.isEmpty
                                  ? null
                                  : _onRotatePages,
                          child: const Text('Rotate PDF Pages'),
                        ),
                      ),
                    ],
                  ),
                  LoadingOverlay(
                      httpState: state.httpStates[HttpStates.ROTATE_PDF],
                      label: 'Rotating your PDF'),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _addPageAngle() {
    final pNo = int.tryParse(pageNoC.text);
    final angle = int.tryParse(pageAngleC.text);
    if (pNo == null || pNo < 1 || pNo > (document?.pagesCount ?? 0)) {
      NotificationService.showSnackbar(
          text: 'Invalid page number', color: Colors.red);
      return;
    }
    if (angle == null) {
      NotificationService.showSnackbar(
          text: 'Invalid angle', color: Colors.red);
      return;
    }
    setState(() => page_angles.put(pNo, angle));
    pageNoC.clear();
    pageAngleC.clear();
  }

  Future<void> _onRotatePages() async {
    // Convert 1-indexed user keys → 0-indexed for backend
    final zeroIndexed = Map.fromEntries(
      page_angles.entries.map((e) => MapEntry(e.key - 1, e.value)),
    );
    bloc.add(RotatePdfEvent(
      rotatePdf: RotatePdf(
        out_file_name: outFileNameC.text.trim().isEmpty
            ? 'rotated_file'
            : outFileNameC.text.trim(),
        file_angle: file_angle,
        maintain_ratio: maintain_ratio,
        page_angles: zeroIndexed,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  _tryRenderingNextThumbnails() async {
    if (document == null) return;
    await _reloadErroredThumbnails(document!);
    if (thumbnails.isEmpty) {
      await _loadThumbnails();
      return;
    }
    if (!controller.hasClients) return;
    final maxScroll = controller.position.maxScrollExtent;
    final scrollPixels = controller.position.pixels;
    if (maxScroll > 0 && (scrollPixels / maxScroll) * 100 >= 90) {
      await _loadThumbnails();
    }
  }

  _reloadErroredThumbnails(PdfDocument doc) async {
    for (final entry in _errorThumbnails()) {
      await _loadThumbnail(document: doc, pageNo: entry.key);
    }
  }

  _loadThumbnails() async {
    if (document == null) throw Exception('Document not yet initialized');
    final loadingCount = _loadingCount();
    if ((loadingCount / pageSize) * 100 > 80) return;
    final total = thumbnails.length;
    for (var i = total;
        i < total + pageSize && i < document!.pagesCount;
        i++) {
      await _loadThumbnail(document: document!, pageNo: i + 1);
    }
  }

  int _loadingCount() =>
      thumbnails.entries.where((t) => t.value.isLoading == true).length;

  List<MapEntry<int, Thumbnail>> _errorThumbnails() =>
      thumbnails.entries.where((t) => t.value.error != null).toList();

  _loadThumbnail({required PdfDocument document, required int pageNo}) async {
    if (thumbnails[pageNo]?.image != null ||
        thumbnails[pageNo]?.isLoading == true) return;
    try {
      if (!mounted) return;
      setState(() => thumbnails.put(pageNo, Thumbnail(isLoading: true)));
      final image =
          await _loadPageImage(document: document, pageNumber: pageNo);
      if (image == null) throw Exception();
      if (!mounted) return;
      setState(() => thumbnails.put(pageNo, Thumbnail(image: image)));
    } catch (_) {
      if (!mounted) return;
      setState(() => thumbnails.put(pageNo, Thumbnail(error: 'failed to render thumbnail')));
    }
  }

  Future<PdfPageImage?> _loadPageImage(
      {required PdfDocument document, required int pageNumber}) async {
    assert(pageNumber > 0);
    try {
      final page = await document.getPage(pageNumber);
      final image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      return image;
    } catch (_) {
      throw Exception('Failed to load pdf page');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _pdfController.dispose();
    outFileNameC.dispose();
    fileAngleC.dispose();
    pageNoC.dispose();
    pageAngleC.dispose();
    super.dispose();
  }
}
