import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/extensions/string_etension.dart';
import 'package:pdf_craft/models/color_info.dart';
import 'package:pdf_craft/models/enums/font.dart';
import 'package:pdf_craft/models/enums/page_no_type.dart';
import 'package:pdf_craft/models/enums/position_info.dart';
import 'package:pdf_craft/models/padding_info.dart';
import 'package:pdf_craft/models/request/page_numbers.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class PageNumberPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  const PageNumberPdfView({super.key, required this.file, this.outFileName});

  @override
  State<PageNumberPdfView> createState() => _PageNumberPdfViewState();
}

class _PageNumberPdfViewState extends State<PageNumberPdfView>
    with ToolResultHandler, ToolViewMixin {
  late final PdfBloc bloc = BlocProvider.of<PdfBloc>(context);

  PageNoType _pageNoType = PageNoType.PAGE_X_OF_Y;
  final TextEditingController _fontSizeC = TextEditingController(text: '20');
  ColorInfo _fillColor = ColorInfo(r: 255, g: 0, b: 0, a: 255);
  PositionInfo _verticalPosition = PositionInfo.START;
  PositionInfo _horizontalPosition = PositionInfo.CENTER;
  final PaddingInfo _padding = PaddingInfo(top: 10, left: 0, bottom: 0, right: 0);
  int _fromPage = 0;
  int? _toPage;
  FontName _fontName = FontName.TIMES_BOLD;
  final TextEditingController _outFileNameC = TextEditingController();

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.pageNumbers]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(ToolStrings.name(context, 'page-numbers')),
        elevation: 2,
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (prev, curr) =>
            prev.httpStates[HttpStates.pageNumbers] != curr.httpStates[HttpStates.pageNumbers],
        listenWhen: (prev, curr) =>
            prev.httpStates[HttpStates.pageNumbers] != curr.httpStates[HttpStates.pageNumbers],
        listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.pageNumbers], successMessage: L10n.current.toolDone),
        builder: (context, state) {
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Output filename
                          TextFormField(
                            controller: _outFileNameC,
                            decoration: InputDecoration(
                              labelText: L10n.of(context).outputFileName,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Page number format
                          _sectionLabel(theme, L10n.of(context).pageNumberFormat),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PageNoType>(
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            initialValue: _pageNoType,
                            items: PageNoType.values
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t.name.split('_').join(' ').capitalize()),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _pageNoType = v);
                            },
                          ),
                          const SizedBox(height: 20),

                          // Font
                          _sectionLabel(theme, 'Font'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<FontName>(
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            menuMaxHeight: 300,
                            initialValue: _fontName,
                            items: FontName.values
                                .map((f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(f.name.split('_').join(' ').capitalize()),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _fontName = v);
                            },
                          ),
                          const SizedBox(height: 20),

                          // Font size
                          _sectionLabel(theme, 'Font Size'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fontSizeC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              suffixText: 'pt',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 20),

                          // Position
                          _sectionLabel(theme, 'Position'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<PositionInfo>(
                                  decoration: InputDecoration(
                                    labelText: L10n.of(context).vertical,
                                    border: const OutlineInputBorder(),
                                  ),
                                  initialValue: _verticalPosition,
                                  items: PositionInfo.values
                                      .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(p.name.capitalize()),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _verticalPosition = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<PositionInfo>(
                                  decoration: InputDecoration(
                                    labelText: L10n.of(context).horizontal,
                                    border: const OutlineInputBorder(),
                                  ),
                                  initialValue: _horizontalPosition,
                                  items: PositionInfo.values
                                      .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(p.name.capitalize()),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _horizontalPosition = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Padding
                          _sectionLabel(theme, 'Padding'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _paddingField('Top', _padding.top, (v) => setState(() => _padding.top = v)),
                              const SizedBox(width: 8),
                              _paddingField('Right', _padding.right, (v) => setState(() => _padding.right = v)),
                              const SizedBox(width: 8),
                              _paddingField('Bottom', _padding.bottom, (v) => setState(() => _padding.bottom = v)),
                              const SizedBox(width: 8),
                              _paddingField('Left', _padding.left, (v) => setState(() => _padding.left = v)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Page range
                          _sectionLabel(theme, L10n.of(context).pageRange),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: L10n.of(context).fromPage,
                                    border: const OutlineInputBorder(),
                                  ),
                                  initialValue: _fromPage.toString(),
                                  onChanged: (v) => setState(() => _fromPage = int.tryParse(v) ?? 0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: L10n.of(context).toPageOptional,
                                    border: const OutlineInputBorder(),
                                  ),
                                  // Fixed: was incorrectly updating _fromPage
                                  onChanged: (v) => setState(() => _toPage = int.tryParse(v)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Color picker
                          _sectionLabel(theme, L10n.of(context).textColor),
                          const SizedBox(height: 8),
                          ColorPicker(
                            pickerColor: Color.fromARGB(
                              _fillColor.a ?? 255,
                              _fillColor.r,
                              _fillColor.g,
                              _fillColor.b,
                            ),
                            onColorChanged: (color) {
                              setState(() => _fillColor = ColorInfo.fromColor(color));
                            },
                          ),
                          const SizedBox(height: 20),

                          // Preview
                          _sectionLabel(theme, 'Preview'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: MediaQuery.of(context).size.width * 1.26,
                            decoration: BoxDecoration(
                              // White because it simulates a paper page
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.surface),
                              border: Border.all(color: theme.dividerColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Align(
                              alignment: _getAlignment(_horizontalPosition, _verticalPosition),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: _padding.left,
                                  top: _padding.top,
                                  right: _padding.right,
                                  bottom: _padding.bottom,
                                ),
                                child: Text(
                                  _pageNoType.type.split('_').join(' '),
                                  style: TextStyle(
                                    fontSize: double.tryParse(_fontSizeC.text) ?? 20,
                                    color: Color.fromARGB(
                                      _fillColor.a ?? 255,
                                      _fillColor.r,
                                      _fillColor.g,
                                      _fillColor.b,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      border: Border(top: BorderSide(color: theme.dividerColor)),
                    ),
                    child: FilledButton(
                      onPressed: _onSubmit,
                      child: Text(ToolStrings.name(context, 'page-numbers')),
                    ),
                  ),
                ],
              ),

              processingOverlay(state.httpStates[HttpStates.pageNumbers], label: L10n.of(context).procWorking),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _paddingField(String label, double value, void Function(double) onChanged) {
    return Expanded(
      child: TextFormField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        initialValue: value.toStringAsFixed(0),
        onChanged: (v) => onChanged(double.tryParse(v) ?? value),
      ),
    );
  }

  Alignment _getAlignment(PositionInfo h, PositionInfo v) {
    final hMap = {
      PositionInfo.START: -1.0,
      PositionInfo.CENTER: 0.0,
      PositionInfo.END: 1.0,
    };
    final vMap = {
      PositionInfo.START: -1.0,
      PositionInfo.CENTER: 0.0,
      PositionInfo.END: 1.0,
    };
    return Alignment(hMap[h] ?? 0, vMap[v] ?? 0);
  }

  void _onSubmit() async {
    final fontSize = int.tryParse(_fontSizeC.text);
    if (fontSize == null || fontSize < 4) {
      NotificationService.showSnackbar(text: L10n.current.invalidFontSize, color: Colors.red);
      return;
    }
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => PageNumbersEvent(
      pageNumber: PageNumbers(
        outFileName: _outFileNameC.text.isEmpty ? 'page_numbers' : _outFileNameC.text,
        pageNoType: _pageNoType,
        size: fontSize,
        fillColor: _fillColor,
        verticalPosition: _verticalPosition,
        horizontalPosition: _horizontalPosition,
        padding: _padding,
        fromPage: _fromPage,
        toPage: _toPage,
        fontName: _fontName,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  @override
  void dispose() {
    _fontSizeC.dispose();
    _outFileNameC.dispose();
    super.dispose();
  }
}
