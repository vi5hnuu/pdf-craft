import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
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
  // Comma-separated list of 0-indexed positions
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
      appBar: AppBar(title: const Text('Add Blank Pages'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.ADD_BLANK_PAGES] != c.httpStates[HttpStates.ADD_BLANK_PAGES],
        listenWhen: (p, c) => p.httpStates[HttpStates.ADD_BLANK_PAGES] != c.httpStates[HttpStates.ADD_BLANK_PAGES],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.ADD_BLANK_PAGES];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Blank pages added successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Inserting blank pages...', color: Colors.lightBlue);
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
                            _field(
                              _positionsC,
                              'Insert After Pages (0-indexed, comma-separated)',
                              hint: 'e.g. 0,2,5 inserts after pages 1, 3, 6',
                            ),
                            const SizedBox(height: 20),
                            const Text('Page Size (points)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('A4 = 595 × 842 pt, Letter = 612 × 792 pt', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _pageWidth.toStringAsFixed(0),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Width (pt)', border: OutlineInputBorder()),
                                    onChanged: (v) => _pageWidth = double.tryParse(v) ?? 595,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _pageHeight.toStringAsFixed(0),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Height (pt)', border: OutlineInputBorder()),
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
                        label: const Text('Add Blank Pages'),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.ADD_BLANK_PAGES]),
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
      NotificationService.showSnackbar(text: 'Enter at least one page position', color: Colors.orange);
      return;
    }
    _bloc.add(AddBlankPagesEvent(
      addBlankPages: AddBlankPages(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        positions:   positions,
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
