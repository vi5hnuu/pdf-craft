import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/stamp-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class StampPdfView extends StatefulWidget {
  final File file;
  const StampPdfView({super.key, required this.file});

  @override
  State<StampPdfView> createState() => _StampPdfViewState();
}

class _StampPdfViewState extends State<StampPdfView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);

  final _outFileNameC = TextEditingController();
  final _fromPageC    = TextEditingController(text: '0');
  final _toPageC      = TextEditingController();

  File? _stampFile;
  double _opacity = 0.5;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Stamp PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.STAMP_PDF];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'PDF stamped successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Stamping PDF...', color: Colors.lightBlue);
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
                            const SizedBox(height: 20),
                            // Stamp image picker
                            const Text('Stamp Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickStamp,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: _stampFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(_stampFile!, fit: BoxFit.contain),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_outlined, size: 36, color: theme.colorScheme.primary),
                                          const SizedBox(height: 6),
                                          const Text('Tap to select stamp image', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Opacity
                            Text('Opacity: ${(_opacity * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 14)),
                            Slider(min: 0.05, max: 1.0, divisions: 19, value: _opacity, onChanged: (v) => setState(() => _opacity = v)),
                            const SizedBox(height: 12),
                            // Page range
                            Row(
                              children: [
                                Expanded(child: _field(_fromPageC, 'From Page (0-indexed)')),
                                const SizedBox(width: 12),
                                Expanded(child: _field(_toPageC, 'To Page (optional)')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _stampFile != null ? _onStamp : null,
                        icon: const Icon(Icons.photo_filter),
                        label: const Text('Stamp PDF'),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.STAMP_PDF]),
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

  void _pickStamp() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _stampFile = File(result.files.single.path!));
    }
  }

  void _onStamp() async {
    if (_stampFile == null) return;
    _bloc.add(StampPdfEvent(
      stampPdf: StampPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        opacity:     _opacity,
        fromPage:    int.tryParse(_fromPageC.text) ?? 0,
        toPage:      _toPageC.text.isNotEmpty ? int.tryParse(_toPageC.text) : null,
        file:  await MultipartFile.fromFile(widget.file.path),
        stamp: await MultipartFile.fromFile(_stampFile!.path),
      ),
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    _fromPageC.dispose();
    _toPageC.dispose();
    super.dispose();
  }
}
