import 'dart:async';
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
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/widgets/PdfEffectPreview.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/singletons/ToolSettingsService.dart';

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
  final _fromPageC    = TextEditingController(text: '1');
  final _toPageC      = TextEditingController();

  int _fontSize = 12;
  Color _color = Colors.black;
  PdfFontName _fontName = PdfFontName.HELVETICA;
  double _topPadding = 20;
  double _bottomPadding = 20;
  /// Page count, so {{total}} reads truthfully in the preview.
  int? _pageCount;

  /// Registered in the tool registry; also the key the settings are stored under.
  static const _toolId = 'header-footer';

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    _loadPageCount();
    _restoreSettings();
  }

  /// Reapplies the last configuration. Stamping the same header across a set of documents used
  /// to mean retyping both lines and resetting four controls each time.
  ///
  /// The page range is deliberately not restored: a range chosen for one document says nothing
  /// about the next.
  Future<void> _restoreSettings() async {
    final saved = await ToolSettingsService().load(_toolId);
    if (saved.isEmpty || !mounted) return;
    setState(() {
      _headerTextC.text = ToolSettingsService.read(saved, 'headerText', _headerTextC.text);
      _footerTextC.text = ToolSettingsService.read(saved, 'footerText', _footerTextC.text);
      _fontSize = ToolSettingsService.read(saved, 'fontSize', _fontSize);
      _color = Color(ToolSettingsService.read(saved, 'color', _color.toARGB32()));
      _topPadding = ToolSettingsService.read(saved, 'topPadding', _topPadding);
      _bottomPadding = ToolSettingsService.read(saved, 'bottomPadding', _bottomPadding);
    });
  }

  Future<void> _rememberSettings() => ToolSettingsService().save(_toolId, {
        'headerText': _headerTextC.text,
        'footerText': _footerTextC.text,
        'fontSize': _fontSize,
        'color': _color.toARGB32(),
        'topPadding': _topPadding,
        'bottomPadding': _bottomPadding,
      });

  /// Restores the defaults and forgets what was stored, so remembering is never a one-way door.
  Future<void> _resetSettings() async {
    await ToolSettingsService().clear(_toolId);
    if (!mounted) return;
    setState(() {
      _headerTextC.clear();
      _footerTextC.clear();
      _fontSize = 12;
      _color = Colors.black;
      _topPadding = 20;
      _bottomPadding = 20;
    });
  }

  /// So {{total}} in the preview shows the document's real length rather than a placeholder.
  Future<void> _loadPageCount() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final count = doc.pagesCount;
      await doc.close();
      if (mounted) setState(() => _pageCount = count);
    } catch (_) {
      // Unreadable here is not worth surfacing: the preview simply shows 1, and the tool
      // itself will report a real failure when it runs.
    }
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
                            // Header and footer text was configured blind: size, colour, padding
                            // and the dynamic tokens were all numbers with no way to see where
                            // they landed until the file came back.
                            PdfEffectPreview(
                              filePath: widget.file.path,
                              caption:
                                  'Approximate placement on page 1 — font metrics differ slightly from the output',
                              overlayBuilder: (ctx, canvas, pagePoints) {
                                final scale = canvas.width / pagePoints.width;
                                final size = _fontSize * scale;
                                Widget line(String text, bool top) => Positioned(
                                      left: 0,
                                      right: 0,
                                      top: top ? _topPadding * scale : null,
                                      bottom: top ? null : _bottomPadding * scale,
                                      child: Text(
                                        _resolveTokens(text),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        style: TextStyle(
                                            fontSize: size, color: _color, height: 1),
                                      ),
                                    );
                                return Stack(children: [
                                  if (_headerTextC.text.trim().isNotEmpty)
                                    line(_headerTextC.text, true),
                                  if (_footerTextC.text.trim().isNotEmpty)
                                    line(_footerTextC.text, false),
                                ]);
                              },
                            ),
                            const SizedBox(height: 16),
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
                                    decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(AppRadius.surface), border: Border.all(color: theme.dividerColor)),
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
                                Expanded(child: _field(_fromPageC, 'From Page')),
                                const SizedBox(width: 12),
                                Expanded(child: _field(_toPageC, 'To Page (optional)')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Padding sliders
                            _labeledSlider('Top Padding', _topPadding, 0, 80, (v) => setState(() => _topPadding = v)),
                            _labeledSlider('Bottom Padding', _bottomPadding, 0, 80, (v) => setState(() => _bottomPadding = v)),
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
                      child: FilledButton.icon(
                        onPressed: _onApply,
                        icon: const Icon(Icons.title),
                        label: const Text('Apply Header/Footer'),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.HEADER_FOOTER], label: 'Adding header & footer'),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => TextFormField(
        controller: c,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  /// Substitutes the dynamic tokens the server understands, so the preview reads the way the
  /// finished page will rather than showing the raw placeholders.
  String _resolveTokens(String text) {
    const page = 1;
    final total = _pageCount ?? 1;
    String roman(int n) {
      const table = [
        [1000, 'm'], [900, 'cm'], [500, 'd'], [400, 'cd'], [100, 'c'], [90, 'xc'],
        [50, 'l'], [40, 'xl'], [10, 'x'], [9, 'ix'], [5, 'v'], [4, 'iv'], [1, 'i'],
      ];
      var rest = n;
      final out = StringBuffer();
      for (final row in table) {
        while (rest >= (row[0] as int)) {
          out.write(row[1]);
          rest -= row[0] as int;
        }
      }
      return out.toString();
    }

    return text
        .replaceAll('{{page_of_total}}', '$page of $total')
        .replaceAll('{{page/total}}', '$page/$total')
        .replaceAll('{{page}}', '$page')
        .replaceAll('{{total}}', '$total')
        .replaceAll('{{ROMAN}}', roman(page).toUpperCase())
        .replaceAll('{{roman}}', roman(page));
  }

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
    // Saved on use rather than on every keystroke: what the user actually ran with is the
    // configuration worth restoring next time.
    unawaited(_rememberSettings());
    _bloc.add(HeaderFooterEvent(
      headerFooter: HeaderFooter(
        outFileName:    _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        headerText:     _headerTextC.text.isNotEmpty  ? _headerTextC.text  : null,
        footerText:     _footerTextC.text.isNotEmpty  ? _footerTextC.text  : null,
        fontSize:       _fontSize,
        color:          ColorInfo(r: _color.red, g: _color.green, b: _color.blue, a: 255),
        fontName:       _fontName,
        // Fields are 1-based because that is how readers count pages; the API is
        // 0-indexed, so the conversion happens here rather than in the user's head.
        fromPage:       _oneBasedToIndex(_fromPageC.text) ?? 0,
        toPage:         _oneBasedToIndex(_toPageC.text),
        topPadding:     _topPadding,
        bottomPadding:  _bottomPadding,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  /// Converts a 1-based page field to the 0-based index the API expects.
  /// Returns null for an empty field so "optional" stays optional.
  int? _oneBasedToIndex(String text) {
    final parsed = int.tryParse(text.trim());
    if (parsed == null) return null;
    return parsed > 0 ? parsed - 1 : 0;
  }

  @override
  void dispose() {
    for (final c in [_outFileNameC, _headerTextC, _footerTextC, _fromPageC, _toPageC]) {
      c.dispose();
    }
    super.dispose();
  }
}
