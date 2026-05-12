import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/crop-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

class CropPdfView extends StatefulWidget {
  final File file;

  const CropPdfView({super.key, required this.file});

  @override
  State<CropPdfView> createState() => _CropPdfViewState();
}

class _CropPdfViewState extends State<CropPdfView> {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();
  double _marginTop = 0;
  double _marginBottom = 0;
  double _marginLeft = 0;
  double _marginRight = 0;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.CROP_PDF] != c.httpStates[HttpStates.CROP_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.CROP_PDF] != c.httpStates[HttpStates.CROP_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.CROP_PDF];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'PDF cropped successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Cropping PDF...', color: Colors.lightBlue);
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
                            const SizedBox(height: 24),
                            const Text('Margins (in points)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildMarginSlider('Top', _marginTop, (v) => setState(() => _marginTop = v)),
                            _buildMarginSlider('Bottom', _marginBottom, (v) => setState(() => _marginBottom = v)),
                            _buildMarginSlider('Left', _marginLeft, (v) => setState(() => _marginLeft = v)),
                            _buildMarginSlider('Right', _marginRight, (v) => setState(() => _marginRight = v)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: _onCrop, child: const Text('Crop PDF')),
                    ),
                  ],
                ),
              ),
              if (state.isLoading(forr: HttpStates.CROP_PDF))
                Container(color: Colors.black54.withValues(alpha: 0.6), child: const Center(child: SpinKitThreeBounce(color: Colors.green, size: 45))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMarginSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(0)} pt'),
        Slider(value: value, min: 0, max: 200, divisions: 40, onChanged: onChanged),
      ],
    );
  }

  void _onCrop() async {
    bloc.add(CropPdfEvent(
      cropPdf: CropPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'cropped_file',
        marginTop: _marginTop,
        marginBottom: _marginBottom,
        marginLeft: _marginLeft,
        marginRight: _marginRight,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    super.dispose();
  }
}
