import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/position.dart';
import 'package:pdf_craft/models/request/watermark-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

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

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
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
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Adding watermark...', color: Colors.lightBlue);
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
                            TextFormField(
                              controller: _outFileNameC,
                              decoration: const InputDecoration(labelText: 'Output File Name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _textC,
                              decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _fontSizeC,
                              keyboardType: TextInputType.number,
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
                                    decoration: BoxDecoration(color: _pickedColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).dividerColor)),
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
              if (state.isLoading(forr: HttpStates.WATERMARK_PDF))
                Container(color: Colors.black54.withValues(alpha: 0.6), child: const Center(child: SpinKitThreeBounce(color: Colors.green, size: 45))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdown(String label, WatermarkPosition value, ValueChanged<WatermarkPosition?> onChanged) {
    return DropdownButtonFormField<WatermarkPosition>(
      value: value,
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
    bloc.add(WatermarkPdfEvent(
      watermarkPdf: WatermarkPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'watermarked_file',
        text: _textC.text.isEmpty ? 'CONFIDENTIAL' : _textC.text,
        fontSize: int.tryParse(_fontSizeC.text) ?? 48,
        color: ColorInfo(r: _pickedColor.red, g: _pickedColor.green, b: _pickedColor.blue, a: _pickedColor.alpha),
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
