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
  final TextEditingController pageNo = TextEditingController();
  final TextEditingController pageAngle = TextEditingController();
  final TextEditingController outFileNameC = TextEditingController();
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);

  final int pageSize = 10;
  final ScrollController controller = ScrollController();
  final Map<int, Thumbnail> thumbnails = {};

  late PdfDocument? document;
  late PdfController _pdfController;
  List<int> _pageIndexes = [];

  // Angle applied to all pages; per-page overrides use page_angles map
  static const _fileAngles = [0, 90, 180, 270];
  int file_angle = 0;

  // Keys are 1-indexed (user-facing); converted to 0-indexed on submit
  Map<int, int> page_angles = {};
  bool maintain_ratio = true;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.file.path),
      initialPage: 1,
    );
    _pdfController.document.then((doc) => setState(() {
          if (!mounted) return;
          document = doc;
          _pageIndexes = List.generate(doc.pagesCount, (index) => index);
          _tryRenderingNextThumbnails();
        }));
    controller.addListener(() => _tryRenderingNextThumbnails());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final md = MediaQuery.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
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
              } else if (httpState?.loading == true) {
                NotificationService.showSnackbar(
                    text: 'Started Rotating', color: Colors.lightBlue);
              }
            },
            builder: (context, state) {
              return Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Output file name
                      Padding(
                        padding:
                            const EdgeInsets.all(12.0).copyWith(bottom: 0),
                        child: TextFormField(
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Output File Name',
                            border: OutlineInputBorder(),
                          ),
                          controller: outFileNameC,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),

                      // All-pages rotation angle chips
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Pages Angle',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: _fileAngles
                                  .map((a) => ChoiceChip(
                                        label: Text(a == 0 ? 'None' : '$a°'),
                                        selected: file_angle == a,
                                        onSelected: (_) =>
                                            setState(() => file_angle = a),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'All pages rotate at this angle; override per page below.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Maintain aspect ratio toggle
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Text(
                              'Maintain Aspect Ratio ',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white70),
                            ),
                            const SizedBox(width: 16),
                            Switch(
                              value: maintain_ratio,
                              onChanged: (value) =>
                                  setState(() => maintain_ratio = value),
                            ),
                          ],
                        ),
                      ),

                      // Preview disclaimer
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'All pages render without overlap; preview is approximate.',
                          style:
                              TextStyle(color: Colors.yellow, fontSize: 12),
                        ),
                      ),

                      // Per-page angle overrides
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Flexible(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      label: Text('Page No.'),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: pageNo,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      label: Text('Angle (0–360)'),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: pageAngle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed:
                                  document == null ? null : _addPageAngle,
                              child: const Text('Add Page Angle'),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: page_angles.entries.map((entry) {
                                return Chip(
                                  onDeleted: () => setState(
                                      () => page_angles.remove(entry.key)),
                                  label: Text(
                                    'Page ${entry.key}: ${entry.value}°',
                                    style:
                                        const TextStyle(color: Colors.black),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  backgroundColor: Colors.white,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      // Thumbnail list
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          scrollDirection: Axis.vertical,
                          itemCount: thumbnails.length,
                          itemBuilder: (context, index) {
                            final pNo = _pageIndexes[index] + 1;
                            final thumbnail = thumbnails[pNo];
                            final thumbW = md.size.width * 0.45;
                            final thumbH = thumbW * 1.37;
                            return Padding(
                              key: ValueKey('page-$pNo'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  RotatablePageWidget(
                                    originalWidth: thumbW,
                                    originalHeight: thumbH,
                                    maintainAspectRatio: maintain_ratio,
                                    // preview uses 1-indexed key — same as stored
                                    rotationAngle:
                                        (page_angles[pNo] ?? file_angle)
                                            .toDouble(),
                                    child: Container(
                                      height: thumbH,
                                      width: thumbW,
                                      child: thumbnail?.isLoading == true
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : thumbnail?.error != null
                                              ? const Center(
                                                  child: Icon(Icons.error))
                                              : thumbnail?.image != null
                                                  ? Image.memory(
                                                      thumbnail!.image!.bytes,
                                                      fit: BoxFit.contain)
                                                  : const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Submit button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        child: FilledButton(
                          onPressed: file_angle == 0 && page_angles.isEmpty
                              ? null
                              : _onRotatePages,
                          child: const Text('Rotate PDF Pages'),
                        ),
                      ),
                    ],
                  ),
                  LoadingOverlay(
                      httpState: state.httpStates[HttpStates.ROTATE_PDF]),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _addPageAngle() {
    final pNo = int.tryParse(pageNo.text);
    final angle = int.tryParse(pageAngle.text);
    if (pNo == null || pNo < 1 || pNo > (document?.pagesCount ?? 0)) {
      NotificationService.showSnackbar(
          text: 'Invalid page number', color: Colors.red);
      return;
    }
    if (angle == null || angle <= 0 || angle > 360) {
      NotificationService.showSnackbar(
          text: 'Invalid angle (1–360)', color: Colors.red);
      return;
    }
    setState(() => page_angles.put(pNo, angle));
    pageNo.clear();
    pageAngle.clear();
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
    final percentScroll = (scrollPixels / maxScroll) * 100;
    if (percentScroll < 90) return;
    await _loadThumbnails();
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
      setState(() {
        if (mounted) thumbnails.put(pageNo, Thumbnail(isLoading: true));
      });
      final image = await _loadPageImage(document: document, pageNumber: pageNo);
      if (image == null) throw Exception();
      setState(() {
        if (mounted) thumbnails.put(pageNo, Thumbnail(image: image));
      });
    } catch (_) {
      setState(() {
        if (mounted)
          thumbnails.put(pageNo, Thumbnail(error: 'failed to render thumbnail'));
      });
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
    pageNo.dispose();
    pageAngle.dispose();
    super.dispose();
  }
}
