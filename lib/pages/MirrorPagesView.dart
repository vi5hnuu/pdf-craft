import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/enums/mirror-direction.dart';
import 'package:pdf_craft/models/request/mirror-pdf.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

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
    resetToolState([HttpStates.MIRROR_PDF]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mirror Pages')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.MIRROR_PDF] != c.httpStates[HttpStates.MIRROR_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.MIRROR_PDF] != c.httpStates[HttpStates.MIRROR_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.MIRROR_PDF], successMessage: 'Pages mirrored'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.MIRROR_PDF]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Flip direction', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    for (final d in MirrorDirection.values)
                      RadioListTile<MirrorDirection>(
                        value: d,
                        groupValue: _direction,
                        onChanged: (v) => setState(() => _direction = v!),
                        title: Text(d.label),
                        secondary: Icon(d == MirrorDirection.horizontal ? Icons.flip : Icons.flip_camera_android),
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
                  label: const Text('Mirror Pages'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.MIRROR_PDF], label: 'Mirroring pages'),
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
