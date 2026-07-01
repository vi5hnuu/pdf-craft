import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/scale-pdf.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Scale PDF: scales page size and content uniformly by a percentage.
class ScalePdfView extends StatefulWidget {
  final File file;
  const ScalePdfView({super.key, required this.file});

  @override
  State<ScalePdfView> createState() => _ScalePdfViewState();
}

class _ScalePdfViewState extends State<ScalePdfView>
    with ToolResultHandler, ToolViewMixin {
  double _percent = 100; // 25%..200%

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.SCALE_PDF]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Scale PDF')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.SCALE_PDF] != c.httpStates[HttpStates.SCALE_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.SCALE_PDF] != c.httpStates[HttpStates.SCALE_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.SCALE_PDF], successMessage: 'PDF scaled'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.SCALE_PDF]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Scale: ${_percent.round()}%',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Both the page size and its content are scaled by this amount.',
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
                  ]),
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
                  label: const Text('Scale PDF'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.SCALE_PDF], label: 'Scaling your PDF'),
          ]);
        },
      ),
    );
  }

  Future<void> _onScale() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ScalePdfEvent(
          scalePdf: ScalePdf(scale: _percent / 100.0, file: file),
          cancelToken: cancelToken,
        ));
  }
}
