import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/models/request/add-blank-pages.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class AddBlankPagesView extends StatefulWidget {
  final File file;
  const AddBlankPagesView({super.key, required this.file});

  @override
  State<AddBlankPagesView> createState() => _AddBlankPagesViewState();
}

class _AddBlankPagesViewState extends State<AddBlankPagesView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);

  final _outFileNameC = TextEditingController();
  // Comma-separated page numbers (1-based) to insert a blank page before.
  final _positionsC   = TextEditingController();

  // A4 dimensions in points (595 x 842) — used as defaults
  double _pageWidth  = 595;
  double _pageHeight = 842;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'add-blank')), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.ADD_BLANK_PAGES] != c.httpStates[HttpStates.ADD_BLANK_PAGES],
        listenWhen: (p, c) => p.httpStates[HttpStates.ADD_BLANK_PAGES] != c.httpStates[HttpStates.ADD_BLANK_PAGES],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.ADD_BLANK_PAGES];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: L10n.current.toolDone, color: Colors.green);
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
                            _field(_outFileNameC, L10n.of(context).outputFileNameOptional),
                            const SizedBox(height: 16),
                            _field(
                              _positionsC,
                              L10n.of(context).insertBlankBefore,
                              hint: L10n.of(context).insertBlankHint,
                            ),
                            const SizedBox(height: 20),
                            Text(L10n.of(context).pageSizePoints, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(L10n.of(context).pageSizeHint, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _pageWidth.toStringAsFixed(0),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: L10n.of(context).widthPt, border: OutlineInputBorder()),
                                    onChanged: (v) => _pageWidth = double.tryParse(v) ?? 595,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _pageHeight.toStringAsFixed(0),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: L10n.of(context).heightPt, border: OutlineInputBorder()),
                                    onChanged: (v) => _pageHeight = double.tryParse(v) ?? 842,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _onAdd,
                        icon: const Icon(Icons.add),
                        label: Text(ToolStrings.name(context, 'add-blank')),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.ADD_BLANK_PAGES], label: L10n.of(context).procWorking),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint}) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
      );

  List<int> _parsePositions() {
    if (_positionsC.text.trim().isEmpty) return [];
    return _positionsC.text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  void _onAdd() async {
    final positions = _parsePositions();
    if (positions.isEmpty) {
      NotificationService.showSnackbar(text: L10n.current.enterPagePosition, color: Colors.orange);
      return;
    }
    _bloc.add(AddBlankPagesEvent(
      addBlankPages: AddBlankPages(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        // Fields are 1-based ("before page N"); the API takes 0-based insertion points.
        positions:   positions.map((p) => p > 0 ? p - 1 : 0).toList(),
        pageWidth:   _pageWidth,
        pageHeight:  _pageHeight,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    _positionsC.dispose();
    super.dispose();
  }
}
