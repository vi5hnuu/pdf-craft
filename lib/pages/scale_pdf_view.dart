import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/scale_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/page_range_selector.dart';

/// Scale PDF: scales page size and content uniformly by a percentage.
class ScalePdfView extends StatefulWidget {
  final File file;
  const ScalePdfView({super.key, required this.file});

  @override
  State<ScalePdfView> createState() => _ScalePdfViewState();
}

class _ScalePdfViewState extends State<ScalePdfView>
    with ToolResultHandler, ToolViewMixin {
  double _percent = 100;
  /// 0-indexed pages the tool applies to. Empty means the whole document.
  final Set<int> _pages = <int>{};
 // 25%..200%

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.scalePdf]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'scale-pdf'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.scalePdf] != c.httpStates[HttpStates.scalePdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.scalePdf] != c.httpStates[HttpStates.scalePdf],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.scalePdf], successMessage: L10n.of(context).pdfScaled),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.scalePdf]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  // Scrollable because the page selector expands to a thumbnail grid, which
                  // overflows a fixed column on a short screen.
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L10n.of(context).scalePercent(_percent.round()),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(L10n.of(context).scaleHelp,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    Slider(
                      value: _percent,
                      min: 25,
                      max: 200,
                      divisions: 35,
                      label: '${_percent.round()}%',
                      onChanged: (v) => setState(() => _percent = v),
                    ),
                    Wrap(spacing: 8, children: [
                      for (final p in [50.0, 100.0, 150.0, 200.0])
                        ChoiceChip(
                          label: Text('${p.round()}%'),
                          selected: _percent == p,
                          onSelected: (_) => setState(() => _percent = p),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    PageRangeSelector(
                      file: widget.file,
                      selected: _pages,
                      onChanged: (pages) => setState(() {
                        _pages
                          ..clear()
                          ..addAll(pages);
                      }),
                    ),
                    ]),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton.icon(
                  onPressed: (loading || _percent == 100) ? null : _onScale,
                  icon: const Icon(Icons.photo_size_select_large),
                  label: Text(ToolStrings.name(context, 'scale-pdf')),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.scalePdf], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Future<void> _onScale() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ScalePdfEvent(
          scalePdf: ScalePdf(scale: _percent / 100.0, pages: _pages.toList()..sort(), file: file),
          cancelToken: cancelToken,
        ));
  }
}
