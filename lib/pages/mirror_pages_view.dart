import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/enum_labels.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/enums/mirror_direction.dart';
import 'package:pdf_craft/models/request/mirror_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// Mirror Pages: flips every page horizontally or vertically (vector-preserving).
class MirrorPagesView extends StatefulWidget {
  final File file;
  const MirrorPagesView({super.key, required this.file});

  @override
  State<MirrorPagesView> createState() => _MirrorPagesViewState();
}

class _MirrorPagesViewState extends State<MirrorPagesView>
    with ToolResultHandler, ToolViewMixin {
  MirrorDirection _direction = MirrorDirection.horizontal;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.mirrorPdf]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'mirror-pages'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.mirrorPdf] != c.httpStates[HttpStates.mirrorPdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.mirrorPdf] != c.httpStates[HttpStates.mirrorPdf],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.mirrorPdf], successMessage: L10n.of(context).pagesMirrored),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.mirrorPdf]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L10n.of(context).flipDirection, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    // RadioGroup supplies the selection to the tiles below it. Besides
                    // replacing the deprecated per-tile groupValue/onChanged, it gives the set
                    // arrow-key navigation, which loose radios never had.
                    RadioGroup<MirrorDirection>(
                      groupValue: _direction,
                      onChanged: (v) => setState(() => _direction = v ?? _direction),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final d in MirrorDirection.values)
                            RadioListTile<MirrorDirection>(
                              value: d,
                              title: Text(d.localizedLabel(context)),
                              secondary: Icon(d == MirrorDirection.horizontal ? Icons.flip : Icons.flip_camera_android),
                            ),
                        ],
                      ),
                    ),
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
                  onPressed: loading ? null : _onMirror,
                  icon: const Icon(Icons.flip),
                  label: Text(ToolStrings.name(context, 'mirror-pages')),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.mirrorPdf], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Future<void> _onMirror() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => MirrorPdfEvent(
          mirrorPdf: MirrorPdf(direction: _direction, file: file),
          cancelToken: cancelToken,
        ));
  }
}
