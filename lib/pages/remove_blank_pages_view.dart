import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/remove_blank_pages.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

class RemoveBlankPagesView extends StatefulWidget {
  final File file;
  const RemoveBlankPagesView({super.key, required this.file});

  @override
  State<RemoveBlankPagesView> createState() => _RemoveBlankPagesViewState();
}

class _RemoveBlankPagesViewState extends State<RemoveBlankPagesView>
    with ToolResultHandler, ToolViewMixin {
  // 0.85 = low sensitivity (only very blank), 0.98 = high sensitivity
  double _sensitivity = 0.95;

  String get _sensitivityLabel {
    if (_sensitivity >= 0.97) return L10n.of(context).sensitivityHigh;
    if (_sensitivity >= 0.92) return L10n.of(context).sensitivityMedium;
    return L10n.of(context).sensitivityLow;
  }

  String _sizeLabel = '';

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    try {
      _sizeLabel = '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB';
    } catch (_) {}
    resetToolState([HttpStates.removeBlankPages]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'remove-blanks'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.removeBlankPages] != c.httpStates[HttpStates.removeBlankPages],
        listenWhen: (p, c) => p.httpStates[HttpStates.removeBlankPages] != c.httpStates[HttpStates.removeBlankPages],
        listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.removeBlankPages], successMessage: L10n.current.blankPagesRemoved),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.removeBlankPages]?.loading == true;
          return Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_sizeLabel.isEmpty ? '' : _sizeLabel,
                        style: theme.textTheme.bodySmall),
                  ),
                ),
                const SizedBox(height: 24),
                Text(L10n.of(context).detectionSensitivity, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Slider(
                  value: _sensitivity,
                  min: 0.85,
                  max: 0.99,
                  divisions: 14,
                  onChanged: (v) => setState(() => _sensitivity = v),
                ),
                Text(_sensitivityLabel,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _onApply,
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_sweep_outlined),
                    label: Text(loading ? L10n.of(context).processingEllipsis : ToolStrings.name(context, 'remove-blanks')),
                  ),
                ),
              ]),
            ),
            processingOverlay(state.httpStates[HttpStates.removeBlankPages], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Future<void> _onApply() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => RemoveBlankPagesEvent(
      removeBlankPages: RemoveBlankPages(
        threshold: _sensitivity,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }
}
