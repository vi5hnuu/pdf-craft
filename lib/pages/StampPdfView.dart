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
import 'package:pdf_craft/theme/app_radius.dart';

class StampPdfView extends StatefulWidget {
  final File file;
  const StampPdfView({super.key, required this.file});

  @override
  State<StampPdfView> createState() => _StampPdfViewState();
}

class _StampPdfViewState extends State<StampPdfView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);

  final _outFileNameC = TextEditingController();
  final _fromPageC    = TextEditingController(text: '1');
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
                            // Stamp PDF picker
                            const Text('Stamp PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickStamp,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(AppRadius.surface),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: _stampFile != null
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.picture_as_pdf, size: 32, color: theme.colorScheme.primary),
                                          const SizedBox(width: 10),
                                          Flexible(child: Text(_stampFile!.path.split('/').last, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.picture_as_pdf_outlined, size: 36, color: theme.colorScheme.primary),
                                          const SizedBox(height: 6),
                                          const Text('Tap to select stamp PDF', style: TextStyle(fontSize: 13)),
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
                                Expanded(child: _field(_fromPageC, 'From Page')),
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
              LoadingOverlay(httpState: state.httpStates[HttpStates.STAMP_PDF], label: 'Stamping your PDF'),
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
    // Backend stamps PDF-on-PDF; image support not yet implemented server-side
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
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
        // Fields are 1-based because that is how readers count pages; the API is
        // 0-indexed, so the conversion happens here rather than in the user's head.
        fromPage:    _oneBasedToIndex(_fromPageC.text) ?? 0,
        toPage:      _oneBasedToIndex(_toPageC.text),
        file:  await MultipartFile.fromFile(widget.file.path),
        stamp: await MultipartFile.fromFile(_stampFile!.path),
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
    _outFileNameC.dispose();
    _fromPageC.dispose();
    _toPageC.dispose();
    super.dispose();
  }
}
