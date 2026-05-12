import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/font-name.dart';
import 'package:pdf_craft/models/request/header-footer.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class HeaderFooterView extends StatefulWidget {
  final File file;
  const HeaderFooterView({super.key, required this.file});

  @override
  State<HeaderFooterView> createState() => _HeaderFooterViewState();
}

class _HeaderFooterViewState extends State<HeaderFooterView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);

  final _outFileNameC = TextEditingController();
  final _headerTextC  = TextEditingController();
  final _footerTextC  = TextEditingController();
  final _fromPageC    = TextEditingController(text: '0');
  final _toPageC      = TextEditingController();

  int _fontSize = 12;
  Color _color = Colors.black;
  PdfFontName _fontName = PdfFontName.HELVETICA;
  double _topPadding = 20;
  double _bottomPadding = 20;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Header & Footer'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.HEADER_FOOTER] != c.httpStates[HttpStates.HEADER_FOOTER],
        listenWhen: (p, c) => p.httpStates[HttpStates.HEADER_FOOTER] != c.httpStates[HttpStates.HEADER_FOOTER],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.HEADER_FOOTER];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Header/footer added successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Adding header/footer...', color: Colors.lightBlue);
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
                            _field(_outFileNameC, 'Output File Name (optional)'),
                            const SizedBox(height: 16),
                            _field(_headerTextC, 'Header Text'),
                            const SizedBox(height: 12),
                            _field(_footerTextC, 'Footer Text'),
                            const SizedBox(height: 16),
                            // Font settings row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<PdfFontName>(
                                    value: _fontName,
                                    decoration: const InputDecoration(labelText: 'Font', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                                    items: PdfFontName.values.map((f) => DropdownMenuItem(value: f, child: Text(f.displayName, style: const TextStyle(fontSize: 13)))).toList(),
                                    onChanged: (v) => setState(() => _fontName = v!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    initialValue: _fontSize.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Size', border: OutlineInputBorder()),
                                    onChanged: (v) => _fontSize = int.tryParse(v) ?? 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Color picker
                            Row(
                              children: [
                                const Text('Text Color:', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: _pickColor,
                                  child: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${_color.red}, ${_color.green}, ${_color.blue}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Page range
                            Row(
                              children: [
                                Expanded(child: _field(_fromPageC, 'From Page (0-indexed)')),
                                const SizedBox(width: 12),
                                Expanded(child: _field(_toPageC, 'To Page (optional)')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Padding sliders
                            _labeledSlider('Top Padding', _topPadding, 0, 80, (v) => setState(() => _topPadding = v)),
                            _labeledSlider('Bottom Padding', _bottomPadding, 0, 80, (v) => setState(() => _bottomPadding = v)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _onApply,
                        icon: const Icon(Icons.title),
                        label: const Text('Apply Header/Footer'),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.HEADER_FOOTER]),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  Widget _labeledSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(0)} pt', style: const TextStyle(fontSize: 13)),
        Slider(min: min, max: max, value: value, onChanged: onChanged),
      ],
    );
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick Text Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (c) => setState(() => _color = c),
            enableAlpha: false,
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }

  void _onApply() async {
    _bloc.add(HeaderFooterEvent(
      headerFooter: HeaderFooter(
        outFileName:    _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        headerText:     _headerTextC.text.isNotEmpty  ? _headerTextC.text  : null,
        footerText:     _footerTextC.text.isNotEmpty  ? _footerTextC.text  : null,
        fontSize:       _fontSize,
        color:          ColorInfo(r: _color.red, g: _color.green, b: _color.blue, a: 255),
        fontName:       _fontName,
        fromPage:       int.tryParse(_fromPageC.text) ?? 0,
        toPage:         _toPageC.text.isNotEmpty ? int.tryParse(_toPageC.text) : null,
        topPadding:     _topPadding,
        bottomPadding:  _bottomPadding,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    for (final c in [_outFileNameC, _headerTextC, _footerTextC, _fromPageC, _toPageC]) {
      c.dispose();
    }
    super.dispose();
  }
}
