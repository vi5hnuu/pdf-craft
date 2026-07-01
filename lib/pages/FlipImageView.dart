import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/flip-image.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Flip Image: mirrors a picture horizontally or vertically.
class FlipImageView extends StatefulWidget {
  final File file;
  const FlipImageView({super.key, required this.file});

  @override
  State<FlipImageView> createState() => _FlipImageViewState();
}

class _FlipImageViewState extends State<FlipImageView>
    with ToolResultHandler, ToolViewMixin {
  bool _horizontal = true;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.FLIP_IMAGE]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Flip Image')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.FLIP_IMAGE] != c.httpStates[HttpStates.FLIP_IMAGE],
        listenWhen: (p, c) => p.httpStates[HttpStates.FLIP_IMAGE] != c.httpStates[HttpStates.FLIP_IMAGE],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.FLIP_IMAGE],
          successMessage: 'Image flipped',
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.FLIP_IMAGE]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Expanded(
                      child: Center(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: _horizontal
                              ? Matrix4.diagonal3Values(-1, 1, 1)
                              : Matrix4.diagonal3Values(1, -1, 1),
                          child: Image.file(widget.file, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: _horizontal,
                      onChanged: (v) => setState(() => _horizontal = v!),
                      title: const Text('Horizontal (mirror left–right)'),
                      secondary: const Icon(Icons.flip),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _horizontal,
                      onChanged: (v) => setState(() => _horizontal = v!),
                      title: const Text('Vertical (mirror top–bottom)'),
                      secondary: const Icon(Icons.flip_camera_android),
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
                  onPressed: loading ? null : _onApply,
                  icon: const Icon(Icons.flip),
                  label: const Text('Flip Image'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.FLIP_IMAGE], label: 'Flipping image'),
          ]);
        },
      ),
    );
  }

  Future<void> _onApply() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => FlipImageEvent(
          flipImage: FlipImage(direction: _horizontal ? 'HORIZONTAL' : 'VERTICAL', file: file),
          cancelToken: cancelToken,
        ));
  }
}
