import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/stamp_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/widgets/placement_box.dart';
import 'package:pdf_craft/widgets/pdf_effect_preview.dart';
import 'package:pdf_craft/utils/page_range.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdfx/pdfx.dart';

class StampPdfView extends StatefulWidget {
  final File file;
  const StampPdfView({super.key, required this.file});

  @override
  State<StampPdfView> createState() => _StampPdfViewState();
}

class _StampPdfViewState extends State<StampPdfView>
    with ToolResultHandler, ToolViewMixin {

  final _outFileNameC = TextEditingController();
  final _fromPageC    = TextEditingController(text: '1');
  final _toPageC      = TextEditingController();

  File? _stampFile;
  double _opacity = 0.5;

  /// Where the stamp goes, as a fraction of the page (origin top-left) — exactly the shape
  /// `StampPdf` already sends as `x_frac`/`y_frac`/`width_frac`/`height_frac`.
  ///
  /// The backend has accepted a placement all along; this screen never offered one, so every
  /// stamp was drawn at its natural size wherever the server chose to put it and the only way
  /// to find out where that was, was to run the tool and open the result.
  Rect _placement = const Rect.fromLTWH(0.35, 0.40, 0.30, 0.20);

  /// Null until the artwork is measured, so the placement box keeps the stamp's own shape
  /// instead of stretching it.
  double? _stampAspect;

  /// 0 until known. The range fields are checked against it, so this screen needs it even
  /// though it shows no page preview.
  int _pageCount = 0;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    resetToolState([HttpStates.stampPdf]);
    _loadPageCount();
  }

  Future<void> _loadPageCount() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final count = doc.pagesCount;
      await doc.close();
      if (mounted) setState(() => _pageCount = count);
    } catch (_) {
      // Left at 0, which the validator reads as "length unknown" and skips the count check
      // rather than blocking input it cannot judge. The run itself still reports a real failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'stamp')), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.stampPdf] != c.httpStates[HttpStates.stampPdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.stampPdf] != c.httpStates[HttpStates.stampPdf],
        listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.stampPdf], successMessage: L10n.current.toolDone),
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _field(_outFileNameC, L10n.of(context).outputFileNameOptional),
                            const SizedBox(height: 20),
                            // Stamp PDF picker
                            Text(ToolStrings.name(context, 'stamp'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickStamp,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(AppRadius.surface),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: _stampFile != null
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.picture_as_pdf, size: 32, color: theme.colorScheme.primary),
                                          const SizedBox(width: 10),
                                          Flexible(child: Text(_stampFile!.path.split('/').last, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.picture_as_pdf_outlined, size: 36, color: theme.colorScheme.primary),
                                          const SizedBox(height: 6),
                                          Text(L10n.of(context).tapToSelectStamp, style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Where the stamp lands, on the real page. Without this the tool
                            // was entirely blind: pick a file, set an opacity, and find out
                            // where the stamp went by opening the result.
                            if (_stampFile != null)
                              PdfEffectPreview(
                                filePath: widget.file.path,
                                interactive: true,
                                caption: L10n.of(context).stampPlacementCaption,
                                overlayBuilder: (context, canvas, pagePoints) => PlacementBox(
                                  rect: _placement,
                                  canvas: canvas,
                                  pagePoints: pagePoints,
                                  aspect: _stampAspect,
                                  onChanged: (r) => setState(() => _placement = r),
                                  child: _stampPreviewArt(),
                                ),
                              ),
                            if (_stampFile != null) const SizedBox(height: 20),
                            // Opacity
                            Text(L10n.of(context).opacityPercent((_opacity * 100).round()), style: const TextStyle(fontSize: 14)),
                            Slider(min: 0.05, max: 1.0, divisions: 19, value: _opacity, onChanged: (v) => setState(() => _opacity = v)),
                            const SizedBox(height: 12),
                            // Page range
                            Row(
                              children: [
                                Expanded(child: _field(_fromPageC, L10n.of(context).fromPage)),
                                const SizedBox(width: 12),
                                Expanded(child: _field(_toPageC, L10n.of(context).toPageOptional)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Above the action bar, never over the document: a banner here sits at the
                    // end of a settings list the user is already scrolling, and cannot cover a
                    // rendered page or a control mid-operation.
                    const BannerAdd(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _stampFile != null ? _onStamp : null,
                        icon: const Icon(Icons.photo_filter),
                        label: Text(ToolStrings.name(context, 'stamp')),
                      ),
                    ),
                  ],
                ),
              ),
              processingOverlay(state.httpStates[HttpStates.stampPdf], label: L10n.of(context).procWorking),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  /// The artwork itself inside the placement box, at the chosen opacity.
  ///
  /// A one-page PDF stamp cannot be shown inline without rendering it, which is more work than
  /// the preview justifies — it gets a labelled placeholder of the right shape instead, which
  /// still answers the question the preview exists for: where on the page will this land.
  Widget? _stampPreviewArt() {
    final stamp = _stampFile;
    if (stamp == null) return null;
    if (stamp.path.toLowerCase().endsWith('.pdf')) {
      return Center(
        child: Icon(Icons.picture_as_pdf,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: _opacity)),
      );
    }
    return Opacity(
      opacity: _opacity,
      child: Image.file(stamp, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    );
  }

  void _pickStamp() async {
    // The stamp may be an image or a one-page PDF; the server identifies which from its bytes.
    // A PNG with transparency is what most people actually want here — a logo or a signature.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'],
    );
    if (result != null && result.files.single.path != null) {
      final picked = File(result.files.single.path!);
      setState(() {
        _stampFile = picked;
        _stampAspect = null;
      });
      await _measureStamp(picked);
    }
  }

  /// Reads the artwork's aspect ratio so the placement box matches its shape.
  ///
  /// An image is decoded directly; a one-page PDF is rendered. Either way a failure just leaves
  /// the box square, which is a worse guess but never a broken screen.
  Future<void> _measureStamp(File stamp) async {
    try {
      double aspect;
      if (stamp.path.toLowerCase().endsWith('.pdf')) {
        final doc = await PdfDocument.openFile(stamp.path);
        final page = await doc.getPage(1);
        aspect = page.width / page.height;
        await page.close();
        await doc.close();
      } else {
        final decoded = await decodeImageFromList(await stamp.readAsBytes());
        aspect = decoded.width / decoded.height;
      }
      if (!mounted || aspect <= 0 || !aspect.isFinite) return;
      setState(() {
        _stampAspect = aspect;
        // Keep the width and derive the height, so the box shows the artwork's real shape.
        final height = (_placement.width / aspect).clamp(0.02, 1.0);
        _placement = Rect.fromLTWH(
          _placement.left,
          _placement.top.clamp(0.0, 1 - height),
          _placement.width,
          height,
        );
      });
    } catch (_) {
      // Unreadable artwork: leave the box as it is rather than blocking the tool.
    }
  }

  void _onStamp() async {
    if (_stampFile == null) return;
    // Before the credit, not after: an impossible range was being charged for and answered with
    // the original file, unstamped.
    final rangeError = pageRangeMessage(
      validatePageRange(
          from: _fromPageC.text, to: _toPageC.text, pageCount: _pageCount),
      _pageCount,
    );
    if (rangeError != null) {
      NotificationService.showSnackbar(text: rangeError, color: Colors.orange);
      return;
    }
    final range = resolvePageRange(
        from: _fromPageC.text, to: _toPageC.text, pageCount: _pageCount);
    final documentUpload = await MultipartFile.fromFile(widget.file.path);
    final stampUpload = await MultipartFile.fromFile(_stampFile!.path);
    if (!mounted) return;
    runTool((cancelToken) => StampPdfEvent(
      stampPdf: StampPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        opacity:     _opacity,
        // Fields are 1-based because that is how readers count pages; the API is
        // 0-indexed, so the conversion happens here rather than in the user's head.
        fromPage:    range.fromIndex,
        toPage:      range.toIndex,
        // All four or none — a partial box is silently ignored by the server.
        xFrac:      _placement.left,
        yFrac:      _placement.top,
        widthFrac:  _placement.width,
        heightFrac: _placement.height,
        file:  documentUpload,
        stamp: stampUpload,
      ), cancelToken: cancelToken));
  }


  @override
  void dispose() {
    _outFileNameC.dispose();
    _fromPageC.dispose();
    _toPageC.dispose();
    super.dispose();
  }
}
