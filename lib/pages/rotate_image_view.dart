import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/rotate_image.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// Rotate Image: rotates a picture in 90° steps.
class RotateImageView extends StatefulWidget {
  final File file;
  const RotateImageView({super.key, required this.file});

  @override
  State<RotateImageView> createState() => _RotateImageViewState();
}

class _RotateImageViewState extends State<RotateImageView>
    with ToolResultHandler, ToolViewMixin {
  int _angle = 90;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.rotateImage]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'img-rotate'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.rotateImage] != c.httpStates[HttpStates.rotateImage],
        listenWhen: (p, c) => p.httpStates[HttpStates.rotateImage] != c.httpStates[HttpStates.rotateImage],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.rotateImage],
          successMessage: L10n.of(context).imageRotated,
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.rotateImage]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: _angle ~/ 90,
                          child: Image.file(
                            widget.file,
                            fit: BoxFit.contain,
                            // The source is a user's photo, often far larger than this preview.
                            cacheWidth: (MediaQuery.sizeOf(context).width *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(L10n.of(context).rotationLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final a in [90, 180, 270])
                        ChoiceChip(
                          label: Text('$a°'),
                          selected: _angle == a,
                          onSelected: (_) => setState(() => _angle = a),
                        ),
                    ]),
                  ]),
                ),
              ),
              _bar(theme, loading, 'Rotate', Icons.rotate_right, _onApply),
            ]),
            processingOverlay(state.httpStates[HttpStates.rotateImage], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Widget _bar(ThemeData theme, bool loading, String label, IconData icon, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: FilledButton.icon(onPressed: loading ? null : onTap, icon: Icon(icon), label: Text(label)),
    );
  }

  Future<void> _onApply() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => RotateImageEvent(
          rotateImage: RotateImage(angle: _angle, file: file),
          cancelToken: cancelToken,
        ));
  }
}
