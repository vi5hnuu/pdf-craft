import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/rotate-image.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

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
    resetToolState([HttpStates.ROTATE_IMAGE]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rotate Image')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.ROTATE_IMAGE] != c.httpStates[HttpStates.ROTATE_IMAGE],
        listenWhen: (p, c) => p.httpStates[HttpStates.ROTATE_IMAGE] != c.httpStates[HttpStates.ROTATE_IMAGE],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.ROTATE_IMAGE],
          successMessage: 'Image rotated',
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.ROTATE_IMAGE]?.loading == true;
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
                          child: Image.file(widget.file, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Rotation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
            processingOverlay(state.httpStates[HttpStates.ROTATE_IMAGE], label: 'Rotating image'),
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
