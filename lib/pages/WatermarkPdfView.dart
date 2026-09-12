import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/position.dart';
import 'package:pdf_craft/models/request/watermark-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdf_craft/widgets/PdfEffectPreview.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/singletons/ToolSettingsService.dart';

class WatermarkPdfView extends StatefulWidget {
  final File file;

  const WatermarkPdfView({super.key, required this.file});

  @override
  State<WatermarkPdfView> createState() => _WatermarkPdfViewState();
}

class _WatermarkPdfViewState extends State<WatermarkPdfView> {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();
  final TextEditingController _textC = TextEditingController(text: 'CONFIDENTIAL');
  final TextEditingController _fontSizeC = TextEditingController(text: '48');
  double _opacity = 0.3;
  double _angle = 45;
  WatermarkPosition _verticalPos = WatermarkPosition.CENTER;
  WatermarkPosition _horizontalPos = WatermarkPosition.CENTER;
  Color _pickedColor = Colors.red;

  /// Registered in the tool registry; also the key the settings are stored under.
  static const _toolId = 'watermark';

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    _restoreSettings();
  }

  /// Reapplies the last configuration. Applying the same watermark across a set of documents
  /// used to mean retyping the text and resetting five controls on every one of them.
  Future<void> _restoreSettings() async {
    final saved = await ToolSettingsService().load(_toolId);
    if (saved.isEmpty || !mounted) return;
    setState(() {
      _textC.text = ToolSettingsService.read(saved, 'text', _textC.text);
      _fontSizeC.text = ToolSettingsService.read(saved, 'fontSize', _fontSizeC.text);
      _opacity = ToolSettingsService.read(saved, 'opacity', _opacity);
      _angle = ToolSettingsService.read(saved, 'angle', _angle);
      _pickedColor = Color(ToolSettingsService.read(saved, 'color', _pickedColor.toARGB32()));
      _verticalPos = _positionFrom(saved['verticalPos'], _verticalPos);
      _horizontalPos = _positionFrom(saved['horizontalPos'], _horizontalPos);
    });
  }

  /// A stored name that no longer matches any position falls back rather than throwing.
  WatermarkPosition _positionFrom(Object? name, WatermarkPosition fallback) {
    for (final position in WatermarkPosition.values) {
      if (position.name == name) return position;
    }
    return fallback;
  }

  Future<void> _rememberSettings() => ToolSettingsService().save(_toolId, {
        'text': _textC.text,
        'fontSize': _fontSizeC.text,
        'opacity': _opacity,
        'angle': _angle,
        'color': _pickedColor.toARGB32(),
        'verticalPos': _verticalPos.name,
        'horizontalPos': _horizontalPos.name,
      });

  /// Restores the tool's defaults and forgets what was stored, so remembering is never a
  /// one-way door.
  Future<void> _resetSettings() async {
    await ToolSettingsService().clear(_toolId);
    if (!mounted) return;
    setState(() {
      _textC.text = 'CONFIDENTIAL';
      _fontSizeC.text = '48';
      _opacity = 0.3;
      _angle = 45;
      _verticalPos = WatermarkPosition.CENTER;
      _horizontalPos = WatermarkPosition.CENTER;
      _pickedColor = Colors.red;
    });
  }

  /// Where the watermark sits, mirroring the server's start/center/end placement.
  Alignment _previewAlignment() {
    final x = switch (_horizontalPos) {
      WatermarkPosition.START => -1.0,
      WatermarkPosition.END => 1.0,
      _ => 0.0,
    };
    final y = switch (_verticalPos) {
      WatermarkPosition.START => -1.0,
      WatermarkPosition.END => 1.0,
      _ => 0.0,
    };
    return Alignment(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watermark PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.WATERMARK_PDF] != c.httpStates[HttpStates.WATERMARK_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.WATERMARK_PDF] != c.httpStates[HttpStates.WATERMARK_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.WATERMARK_PDF];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Watermark applied successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PdfEffectPreview(
                              filePath: widget.file.path,
                              caption:
                                  'Approximate placement — font metrics differ slightly from the output',
                              overlayBuilder: (ctx, canvas, pagePoints) {
                                final text = _textC.text.isEmpty
                                    ? 'CONFIDENTIAL'
                                    : _textC.text;
                                final pt = double.tryParse(_fontSizeC.text) ?? 48;
                                // The size is in PDF points, so scale it by how much the page
                                // was shrunk to fit — otherwise it reads far too large here.
                                final scaled = pt * (canvas.width / pagePoints.width);
                                return Align(
                                  alignment: _previewAlignment(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Transform.rotate(
                                      angle: -_angle * 3.1415926535 / 180,
                                      child: Text(
                                        text,
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                        style: TextStyle(
                                          fontSize: scaled,
                                          fontWeight: FontWeight.bold,
                                          color: _pickedColor
                                              .withValues(alpha: _opacity),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _outFileNameC,
                              decoration: const InputDecoration(labelText: 'Output File Name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _textC,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _fontSizeC,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Font Size', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text('Color: '),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: _pickColor,
                                  child: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(color: _pickedColor, borderRadius: BorderRadius.circular(AppRadius.surface), border: Border.all(color: Theme.of(context).dividerColor)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(onPressed: _pickColor, child: const Text('Change')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('Opacity: ${_opacity.toStringAsFixed(2)}'),
                            Slider(value: _opacity, min: 0.05, max: 1.0, divisions: 19, onChanged: (v) => setState(() => _opacity = v)),
                            Text('Angle: ${_angle.toStringAsFixed(0)}°'),
                            Slider(value: _angle, min: 0, max: 360, divisions: 36, onChanged: (v) => setState(() => _angle = v)),
                            const SizedBox(height: 8),
                            _buildDropdown('Vertical Position', _verticalPos, (v) => setState(() => _verticalPos = v!)),
                            const SizedBox(height: 8),
                            _buildDropdown('Horizontal Position', _horizontalPos, (v) => setState(() => _horizontalPos = v!)),
                            const SizedBox(height: 4),
                            // Settings are remembered, so there has to be a way back out of them.
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _resetSettings,
                                child: const Text('Reset to defaults'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: _onWatermark, child: const Text('Apply Watermark')),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.WATERMARK_PDF], label: 'Adding watermark'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdown(String label, WatermarkPosition value, ValueChanged<WatermarkPosition?> onChanged) {
    return DropdownButtonFormField<WatermarkPosition>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: WatermarkPosition.values.map((p) => DropdownMenuItem(value: p, child: Text(p.displayName))).toList(),
      onChanged: onChanged,
    );
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _pickedColor,
            onColorChanged: (c) => setState(() => _pickedColor = c),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }

  void _onWatermark() async {
    // Saved on use rather than on every keystroke: what the user actually ran with is the
    // configuration worth restoring next time.
    unawaited(_rememberSettings());
    bloc.add(WatermarkPdfEvent(
      watermarkPdf: WatermarkPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'watermarked_file',
        text: _textC.text.isEmpty ? 'CONFIDENTIAL' : _textC.text,
        fontSize: int.tryParse(_fontSizeC.text) ?? 48,
        color: ColorInfo.fromColor(_pickedColor),
        opacity: _opacity,
        angle: _angle,
        verticalPosition: _verticalPos,
        horizontalPosition: _horizontalPos,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    _textC.dispose();
    _fontSizeC.dispose();
    super.dispose();
  }
}
