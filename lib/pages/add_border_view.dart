import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/border_image.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// Add Border: frames an image with a solid coloured border.
class AddBorderView extends StatefulWidget {
  final File file;
  const AddBorderView({super.key, required this.file});

  @override
  State<AddBorderView> createState() => _AddBorderViewState();
}

class _AddBorderViewState extends State<AddBorderView>
    with ToolResultHandler, ToolViewMixin {
  double _width = 20;
  Color _color = Colors.black;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.borderImage]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'img-border'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.borderImage] != c.httpStates[HttpStates.borderImage],
        listenWhen: (p, c) => p.httpStates[HttpStates.borderImage] != c.httpStates[HttpStates.borderImage],
        listener: (context, state) => handleToolState(
          state.httpStates[HttpStates.borderImage],
          successMessage: L10n.of(context).borderAdded,
          onDone: (f) => OpenFile.open(f.path),
        ),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.borderImage]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          // Preview border (scaled down visually).
                          padding: EdgeInsets.all(_width / 4),
                          color: _color,
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
                    const SizedBox(height: 12),
                    Row(children: [
                      Text(L10n.of(context).widthLabel),
                      Expanded(
                        child: Slider(
                          value: _width,
                          min: 2,
                          max: 100,
                          divisions: 49,
                          label: '${_width.round()} px',
                          onChanged: (v) => setState(() => _width = v),
                        ),
                      ),
                      Text('${_width.round()} px'),
                    ]),
                    Row(children: [
                      Text(L10n.of(context).colorPlain),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _pickColor,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _color,
                            borderRadius: BorderRadius.circular(AppRadius.surface),
                            border: Border.all(color: theme.dividerColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Quick presets.
                      for (final c in [Colors.black, Colors.white, Colors.grey, Colors.brown])
                        GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.dividerColor),
                            ),
                          ),
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
                  onPressed: loading ? null : _onApply,
                  icon: const Icon(Icons.border_outer),
                  label: Text(ToolStrings.name(context, 'img-border')),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.borderImage], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L10n.of(context).pickColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (c) => setState(() => _color = c),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).done))],
      ),
    );
  }

  Future<void> _onApply() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => BorderImageEvent(
          borderImage: BorderImage(
            width: _width.round(),
            r: (_color.r * 255).round(),
            g: (_color.g * 255).round(),
            b: (_color.b * 255).round(),
            file: file,
          ),
          cancelToken: cancelToken,
        ));
  }
}
