import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/font.dart';
import 'package:pdf_craft/models/enums/page-no-type.dart';
import 'package:pdf_craft/models/enums/position-info.dart';
import 'package:pdf_craft/models/padding-info.dart';
import 'package:pdf_craft/models/request/page-numbers.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class PageNumberPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  PageNumberPdfView({super.key, required this.file, this.outFileName});

  @override
  State<PageNumberPdfView> createState() => _PageNumberPdfViewState();
}

class _PageNumberPdfViewState extends State<PageNumberPdfView> {
  late final PdfBloc bloc = BlocProvider.of<PdfBloc>(context);

  PageNoType _pageNoType = PageNoType.PAGE_X_OF_Y;
  final TextEditingController _fontSizeC = TextEditingController(text: '20');
  ColorInfo _fillColor = ColorInfo(r: 255, g: 0, b: 0, a: 255);
  PositionInfo _verticalPosition = PositionInfo.START;
  PositionInfo _horizontalPosition = PositionInfo.CENTER;
  PaddingInfo _padding = PaddingInfo(top: 10, left: 0, bottom: 0, right: 0);
  int _fromPage = 0;
  int? _toPage;
  FontName _fontName = FontName.TIMES_BOLD;
  final TextEditingController _outFileNameC = TextEditingController();

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Page Numbers'),
        elevation: 2,
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (prev, curr) =>
            prev.httpStates[HttpStates.PAGE_NUMBERS] != curr.httpStates[HttpStates.PAGE_NUMBERS],
        listenWhen: (prev, curr) =>
            prev.httpStates[HttpStates.PAGE_NUMBERS] != curr.httpStates[HttpStates.PAGE_NUMBERS],
        listener: (context, state) {
          final httpState = state.httpStates[HttpStates.PAGE_NUMBERS];
          if (httpState?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Page numbers added successfully', color: Colors.green);
            if (httpState?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': (httpState!.extras!['savedFile'] as File).path},
              );
            }
          } else if (httpState?.error != null) {
            NotificationService.showSnackbar(text: httpState!.error!, color: Colors.red);
          }
        },
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
                            decoration: const InputDecoration(
                              labelText: 'Output File Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Page number format
                          _sectionLabel(theme, 'Page Number Format'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PageNoType>(
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            value: _pageNoType,
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
                            value: _fontName,
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
                                  decoration: const InputDecoration(
                                    labelText: 'Vertical',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _verticalPosition,
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
                                  decoration: const InputDecoration(
                                    labelText: 'Horizontal',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _horizontalPosition,
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
                          _sectionLabel(theme, 'Page Range'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'From page',
                                    border: OutlineInputBorder(),
                                  ),
                                  initialValue: _fromPage.toString(),
                                  onChanged: (v) => setState(() => _fromPage = int.tryParse(v) ?? 0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'To page (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  // Fixed: was incorrectly updating _fromPage
                                  onChanged: (v) => setState(() => _toPage = int.tryParse(v)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Color picker
                          _sectionLabel(theme, 'Text Color'),
                          const SizedBox(height: 8),
                          ColorPicker(
                            pickerColor: Color.fromARGB(
                              _fillColor.a ?? 255,
                              _fillColor.r,
                              _fillColor.g,
                              _fillColor.b,
                            ),
                            onColorChanged: (color) {
                              setState(() => _fillColor = ColorInfo(
                                    r: color.red,
                                    g: color.green,
                                    b: color.blue,
                                    a: color.alpha,
                                  ));
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
                              borderRadius: BorderRadius.circular(8),
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
                      child: const Text('Apply Page Numbers'),
                    ),
                  ),
                ],
              ),

              LoadingOverlay(httpState: state.httpStates[HttpStates.PAGE_NUMBERS]),
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
      NotificationService.showSnackbar(text: 'Invalid font size (min 4)', color: Colors.red);
      return;
    }
    bloc.add(PageNumbersEvent(
      pageNumber: PageNumbers(
        out_file_name: _outFileNameC.text.isEmpty ? 'page_numbers' : _outFileNameC.text,
        page_no_type: _pageNoType,
        size: fontSize,
        fill_color: _fillColor,
        vertical_position: _verticalPosition,
        horizontal_position: _horizontalPosition,
        padding: _padding,
        from_page: _fromPage,
        to_page: _toPage,
        font_name: _fontName,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _fontSizeC.dispose();
    _outFileNameC.dispose();
    super.dispose();
  }
}
