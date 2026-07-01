import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/split-by-size.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Split by Size: breaks a PDF into multiple parts, each at most N MB, returned
/// as a ZIP that is opened in the device's default handler.
class SplitBySizeView extends StatefulWidget {
  final File file;
  const SplitBySizeView({super.key, required this.file});

  @override
  State<SplitBySizeView> createState() => _SplitBySizeViewState();
}

class _SplitBySizeViewState extends State<SplitBySizeView>
    with ToolResultHandler, ToolViewMixin {
  final _sizeC = TextEditingController(text: '5');
  static const _presets = [2.0, 5.0, 10.0];

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.SPLIT_BY_SIZE]);
  }

  @override
  void dispose() {
    _sizeC.dispose();
    super.dispose();
  }

  double get _sizeMb => double.tryParse(_sizeC.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Split by Size')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.SPLIT_BY_SIZE] != c.httpStates[HttpStates.SPLIT_BY_SIZE],
        listenWhen: (p, c) => p.httpStates[HttpStates.SPLIT_BY_SIZE] != c.httpStates[HttpStates.SPLIT_BY_SIZE],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.SPLIT_BY_SIZE],
          successMessage: 'PDF split',
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.SPLIT_BY_SIZE]?.loading == true;
          final valid = _sizeMb > 0;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Maximum size per part',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      'Each output PDF will be at or below this size. A single page larger than the '
                      'limit becomes its own part.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _sizeC,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Size',
                        suffixText: 'MB',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      for (final p in _presets)
                        ChoiceChip(
                          label: Text('${p.toStringAsFixed(0)} MB'),
                          selected: _sizeMb == p,
                          onSelected: (_) => setState(() => _sizeC.text = p.toStringAsFixed(0)),
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
                  onPressed: valid && !loading ? _onSplit : null,
                  icon: const Icon(Icons.call_split),
                  label: const Text('Split (ZIP)'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.SPLIT_BY_SIZE], label: 'Splitting your PDF'),
          ]);
        },
      ),
    );
  }

  Future<void> _onSplit() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => SplitBySizeEvent(
          splitBySize: SplitBySize(outFileName: 'split_by_size', maxSizeMb: _sizeMb, file: file),
          cancelToken: cancelToken,
        ));
  }
}
