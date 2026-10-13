import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/extensions/map_entensions.dart';
import 'package:pdf_craft/models/request/rotate_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/rotatable_item.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/utils/debouncer.dart';
import 'package:pdf_craft/widgets/tool_pane.dart';
import 'package:pdf_craft/utils/responsive.dart';

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

class _RotatePdfViewState extends State<RotatePdfView>
    with ToolResultHandler, ToolViewMixin {
  final TextEditingController pageNoC = TextEditingController();
  final TextEditingController pageAngleC = TextEditingController();
  final TextEditingController outFileNameC = TextEditingController();
  // Separate controller for all-page angle text field
  final TextEditingController fileAngleC = TextEditingController(text: '0');
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);

  final int pageSize = 10;
  final ScrollController controller = ScrollController();
  final Debouncer _scrollDebounce = Debouncer(milliseconds: 120);
  /// Rendered page thumbnails, keyed by 1-based page number.
  ///
  /// Deliberately uncapped. An LRU here was wrong twice over: this map's *size* is the cursor
  /// for what to load next and the count of rows to render, so evicting from it stalled loading
  /// at the cap and blanked the rows that had been dropped. The memory it was defending against
  /// is already gone — these render at the ~180dp they are drawn at rather than the page's
  /// intrinsic size, which is roughly fifty times smaller per page.
  final Map<int, Thumbnail> thumbnails = {};

  /// Width, in logical pixels, a thumbnail is painted at. Rendering at the page's intrinsic
  /// size produced bitmaps many times larger than the box they are drawn in.
  static const double _thumbnailWidth = 180;

  PdfDocument? document;
  late PdfController _pdfController;
  List<int> _pageIndexes = [];

  int fileAngle = 0;
  // Keys are 1-indexed (user-facing); converted to 0-indexed on submit
  Map<int, int> pageAngles = {};
  bool maintainRatio = true;

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
    // Debounced: _tryRenderingNextThumbnails awaits a reload and walks the whole cache, and
    // this fired on every scroll tick. Debouncer already exists for exactly this.
    controller.addListener(() => _scrollDebounce.run(_tryRenderingNextThumbnails));
    fileAngleC.addListener(() {
      final v = int.tryParse(fileAngleC.text) ?? 0;
      if (v != fileAngle) setState(() => fileAngle = v);
    });
    super.initState();
    resetToolState([HttpStates.rotatePdf]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'rotate'))),
      body: ToolPane(child: FutureBuilder(
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
                previous.httpStates[HttpStates.rotatePdf] !=
                current.httpStates[HttpStates.rotatePdf],
            listenWhen: (previous, current) =>
                previous.httpStates[HttpStates.rotatePdf] !=
                current.httpStates[HttpStates.rotatePdf],
            listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.rotatePdf], successMessage: L10n.current.toolDone),
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
                              decoration: InputDecoration(
                                labelText: L10n.of(context).outputFileName,
                                border: const OutlineInputBorder(),
                              ),
                              controller: outFileNameC,
                            ),
                            const SizedBox(height: 16),

                            // ── All-pages angle ────────────────────────
                            Text(L10n.of(context).allPagesAngle,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: fileAngleC,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: L10n.of(context).angleHint,
                                border: const OutlineInputBorder(),
                                suffixText: '°',
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Quick-preset chips — tap to fill the field
                            Wrap(
                              spacing: 6,
                              children: _presets.map((a) {
                                final selected = fileAngle == a;
                                return ActionChip(
                                  label: Text(a == 0 ? L10n.of(context).rotateNone : '$a°'),
                                  backgroundColor: selected
                                      ? primary.withValues(alpha: 0.18)
                                      : null,
                                  side: selected
                                      ? BorderSide(color: primary)
                                      : null,
                                  onPressed: () {
                                    fileAngleC.text = '$a';
                                    setState(() => fileAngle = a);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              L10n.of(context).rotateAllHint,
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
                                title: Text(L10n.of(context).maintainAspect),
                                subtitle: Text(
                                  maintainRatio
                                      ? L10n.of(context).rotateSwapHint
                                      : L10n.of(context).rotateKeepHint,
                                  style: theme.textTheme.bodySmall,
                                ),
                                value: maintainRatio,
                                onChanged: (v) =>
                                    setState(() => maintainRatio = v),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              L10n.of(context).previewApproximate,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.amber),
                            ),
                            const SizedBox(height: 16),

                            // ── Per-page angle override ────────────────
                            Text(L10n.of(context).perPageAngle,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      label: Text(L10n.of(context).pageNo),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    controller: pageNoC,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      label: Text(L10n.of(context).angleLabel),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      suffixText: '°',
                                    ),
                                    controller: pageAngleC,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: document == null ? null : _addPageAngle,
                                  child: Text(L10n.of(context).add),
                                ),
                              ],
                            ),
                            if (pageAngles.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: pageAngles.entries.map((entry) {
                                  return Chip(
                                    label: Text(
                                        'p${entry.key}: ${entry.value}°',
                                        style: const TextStyle(fontSize: 12)),
                                    onDeleted: () => setState(
                                        () => pageAngles.remove(entry.key)),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // ── Thumbnail previews ─────────────────────
                            if (thumbnails.isNotEmpty)
                              Text(L10n.of(context).preview,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ...List.generate(thumbnails.length, (index) {
                              final pNo = _pageIndexes[index] + 1;
                              final thumbnail = thumbnails[pNo];
                              final thumbW = toolContentWidthOf(context) * 0.42;
                              final thumbH = thumbW * 1.37;
                              return Padding(
                                key: ValueKey('page-$pNo'),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Center(
                                  child: RotatablePageWidget(
                                    originalWidth: thumbW,
                                    originalHeight: thumbH,
                                    maintainAspectRatio: maintainRatio,
                                    rotationAngle:
                                        (pageAngles[pNo] ?? fileAngle)
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
                                            BorderRadius.circular(AppRadius.surface),
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
                                                          BorderRadius.circular(AppRadius.surface),
                                                      // cacheWidth bounds the decoded
                                                      // texture: without it Flutter decodes
                                                      // the JPEG at full size however small
                                                      // it is drawn.
                                                      child: Image.memory(
                                                          thumbnail!.image!.bytes,
                                                          fit: BoxFit.contain,
                                                          cacheWidth: (thumbW *
                                                                  MediaQuery
                                                                      .devicePixelRatioOf(
                                                                          context))
                                                              .round()))
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
                        padding: EdgeInsets.fromLTRB(14, 14, 14,
                            14 + MediaQuery.viewPaddingOf(context).bottom),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          border:
                              Border(top: BorderSide(color: theme.dividerColor)),
                        ),
                        child: FilledButton(
                          // `loading` in the predicate too. The overlay only blocks the screen
                          // once the bloc has emitted loading, and _onRotatePages first awaits
                          // reading the file — so in that gap the button stayed live and two
                          // fast taps dispatched two uploads and debited twice. The neighbouring
                          // tools (scale, mirror) already guarded this.
                          onPressed: (state.httpStates[HttpStates.rotatePdf]?.loading == true) ||
                                  (fileAngle == 0 && pageAngles.isEmpty)
                              ? null
                              : _onRotatePages,
                          child: Text(ToolStrings.name(context, 'rotate')),
                        ),
                      ),
                    ],
                  ),
                  processingOverlay(state.httpStates[HttpStates.rotatePdf],
                      label: L10n.of(context).rotatingPdf),
                ],
              );
            },
          );
        },
      )),
    );
  }

  void _addPageAngle() {
    final pNo = int.tryParse(pageNoC.text);
    final angle = int.tryParse(pageAngleC.text);
    if (pNo == null || pNo < 1 || pNo > (document?.pagesCount ?? 0)) {
      NotificationService.showSnackbar(
          text: L10n.current.invalidPageNumber, color: Colors.red);
      return;
    }
    if (angle == null) {
      NotificationService.showSnackbar(
          text: L10n.current.invalidAngle, color: Colors.red);
      return;
    }
    setState(() => pageAngles.put(pNo, angle));
    pageNoC.clear();
    pageAngleC.clear();
  }

  Future<void> _onRotatePages() async {
    // Convert 1-indexed user keys → 0-indexed for backend
    final zeroIndexed = Map.fromEntries(
      pageAngles.entries.map((e) => MapEntry(e.key - 1, e.value)),
    );
    final uploadFile = await readForUpload(widget.file);
    if (uploadFile == null) return;
    if (!mounted) return;
    runTool((cancelToken) => RotatePdfEvent(
      rotatePdf: RotatePdf(
        outFileName: outFileNameC.text.trim().isEmpty
            ? 'rotated_file'
            : outFileNameC.text.trim(),
        fileAngle: fileAngle,
        maintainRatio: maintainRatio,
        pageAngles: zeroIndexed,
        file: uploadFile,
      ), cancelToken: cancelToken));
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
        thumbnails[pageNo]?.isLoading == true) {
      return;
    }
    try {
      if (!mounted) return;
      setState(() => thumbnails.put(pageNo, Thumbnail(isLoading: true)));
      final image =
          await _loadPageImage(document: document, pageNumber: pageNo);
      if (image == null) throw Exception();
      _setThumbnail(pageNo, Thumbnail(image: image));
    } catch (_) {
      _setThumbnail(pageNo, Thumbnail(error: L10n.current.thumbnailFailed));
    }
  }

  void _setThumbnail(int pageNo, Thumbnail thumbnail) {
    if (!mounted) return;
    setState(() => thumbnails.put(pageNo, thumbnail));
  }

  Future<PdfPageImage?> _loadPageImage(
      {required PdfDocument document, required int pageNumber}) async {
    assert(pageNumber > 0);
    // Read before the first await: it comes from the element's inherited widgets.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    try {
      final page = await document.getPage(pageNumber);
      // Bounded by the width it is drawn at rather than the page's own size: an A4 page at
      // intrinsic size is a multi-megabyte bitmap for a thumbnail.
      final target = _thumbnailWidth * ratio;
      final width = page.width <= target ? page.width : target;
      final image = await page.render(
        width: width,
        height: page.height / page.width * width,
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
    _scrollDebounce.dispose();
    controller.dispose();
    _pdfController.dispose();
    outFileNameC.dispose();
    fileAngleC.dispose();
    pageNoC.dispose();
    pageAngleC.dispose();
    // Disposing the controller does not close the document (see PdfPreview), so the native
    // handle and its page cache leaked on every visit to this screen.
    document?.close();
    thumbnails.clear();
    super.dispose();
  }
}
