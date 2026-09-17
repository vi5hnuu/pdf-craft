import 'dart:io';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/n_up.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class NUpPdfView extends StatefulWidget {
  final File file;
  const NUpPdfView({super.key, required this.file});

  @override
  State<NUpPdfView> createState() => _NUpPdfViewState();
}

class _NUpPdfViewState extends State<NUpPdfView>
    with ToolResultHandler, ToolViewMixin {
  int _nUp = 2;
  // Read once (off the build path) so rebuilds don't re-stat the file.
  String _sizeLabel = '';

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    try {
      _sizeLabel = '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB';
    } catch (_) {}
    resetToolState([HttpStates.nUpPdf]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'n-up'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.nUpPdf] != c.httpStates[HttpStates.nUpPdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.nUpPdf] != c.httpStates[HttpStates.nUpPdf],
        listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.nUpPdf], successMessage: L10n.current.nUpDone),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.nUpPdf]?.loading == true;
          return Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_sizeLabel, style: theme.textTheme.bodySmall),
                  ),
                ),
                const SizedBox(height: 24),
                Text(L10n.of(context).pagesPerSheet, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  _layoutOption(theme, 2, L10n.of(context).nUpTwo, L10n.of(context).nUpLandscapeSide, Icons.view_agenda_outlined),
                  const SizedBox(width: 12),
                  _layoutOption(theme, 4, L10n.of(context).nUpFour, L10n.of(context).nUpPortraitGrid, Icons.grid_view_outlined),
                ]),
                const SizedBox(height: 20),
                // The real pages, tiled the way the output will tile them. Two icon chips were
                // the only signal before, so "2-Up" and "4-Up" meant whatever the user guessed.
                Expanded(child: _NUpPreview(file: widget.file, nUp: _nUp)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _onApply,
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.view_module_outlined),
                    label: Text(loading
                        ? L10n.of(context).processingEllipsis
                        : L10n.of(context).nUpCreate(_nUp)),
                  ),
                ),
              ]),
            ),
            processingOverlay(state.httpStates[HttpStates.nUpPdf], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Widget _layoutOption(ThemeData theme, int n, String title, String subtitle, IconData icon) {
    final selected = _nUp == n;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _nUp = n),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primaryContainer : theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.surface),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            // On a primaryContainer surface the correct foreground is
            // onPrimaryContainer — using `primary` here made the icon wash out.
            Icon(icon,
                color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                size: 32),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? theme.colorScheme.onPrimaryContainer : null,
            )),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  Future<void> _onApply() async {
    final baseName = widget.file.path.split('/').last.replaceAll('.pdf', '');
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => NUpPdfEvent(
      nUp: NUp(
        nUp: _nUp,
        outFileName: '${baseName}_${_nUp}up',
        file: uploadFile,
      ), cancelToken: cancelToken));
  }
}

/// Shows the document's first [nUp] pages arranged on one sheet, the way the output arranges
/// them: 2-Up puts two portrait pages side by side on a landscape sheet, 4-Up puts four in a
/// 2x2 grid on a portrait sheet.
///
/// Rendered locally from the file the user already picked — no request, so the preview costs
/// nothing and works offline.
class _NUpPreview extends StatefulWidget {
  final File file;
  final int nUp;

  const _NUpPreview({required this.file, required this.nUp});

  @override
  State<_NUpPreview> createState() => _NUpPreviewState();
}

class _NUpPreviewState extends State<_NUpPreview> {
  /// Thumbnails of the first few pages, in order. Fewer than [widget.nUp] when the document is
  /// shorter, which the sheet then shows with blank cells — which is what the output does too.
  List<Uint8List>? _pages;
  double _pageAspect = 595 / 842;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_NUpPreview old) {
    super.didUpdateWidget(old);
    if (old.nUp != widget.nUp || old.file.path != widget.file.path) _load();
  }

  Future<void> _load() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final count = math.min(widget.nUp, doc.pagesCount);
      final thumbs = <Uint8List>[];
      for (var i = 1; i <= count; i++) {
        final page = await doc.getPage(i);
        if (i == 1) _pageAspect = page.width / page.height;
        // Small: several of these sit on one sheet at thumbnail size.
        final image = await page.render(
          width: 220,
          height: 220 / (page.width / page.height),
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        await page.close();
        if (image != null) thumbs.add(image.bytes);
      }
      await doc.close();
      if (!mounted) return;
      setState(() => _pages = thumbs);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_failed) {
      return Center(
        child: Text(L10n.of(context).previewUnavailable,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    final pages = _pages;
    if (pages == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2-Up lays two portrait pages across a landscape sheet; 4-Up keeps the sheet portrait.
    const columns = 2;
    final rows = widget.nUp == 2 ? 1 : 2;
    final sheetAspect = (_pageAspect * columns) / rows;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: sheetAspect,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(AppRadius.surface),
              ),
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                childAspectRatio: _pageAspect,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = 0; i < widget.nUp; i++)
                    DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor)),
                      child: i < pages.length
                          ? Image.memory(pages[i], fit: BoxFit.contain)
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(L10n.of(context).nUpPreviewCaption,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}
