import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_craft/models/request/stamp-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrStampPdfView extends StatefulWidget {
  final File file;
  const QrStampPdfView({super.key, required this.file});

  @override
  State<QrStampPdfView> createState() => _QrStampPdfViewState();
}

class _QrStampPdfViewState extends State<QrStampPdfView> {
  final _qrDataC = TextEditingController();
  final _outFileNameC = TextEditingController();
  final _fromPageC = TextEditingController(text: '0');
  final _toPageC = TextEditingController();
  final _qrKey = GlobalKey();

  String _qrPreview = '';
  double _opacity = 0.8;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _qrDataC.addListener(() {
      if (_qrDataC.text.trim() != _qrPreview) {
        setState(() => _qrPreview = _qrDataC.text.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Stamp')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.STAMP_PDF] != c.httpStates[HttpStates.STAMP_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.STAMP_PDF];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(
                text: 'QR stamp applied', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {
                  'pdfFilePath': (s!.extras!['savedFile'] as File).path,
                },
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(
                text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(
                text: 'Stamping QR code…', color: Colors.lightBlue);
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
                            // QR data input
                            TextFormField(
                              controller: _qrDataC,
                              decoration: const InputDecoration(
                                labelText: 'URL or text for QR code',
                                hintText: 'https://example.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.qr_code),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Live QR preview
                            if (_qrPreview.isNotEmpty) ...[
                              Text('Preview',
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Center(
                                child: RepaintBoundary(
                                  key: _qrKey,
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(12),
                                    child: QrImageView(
                                      data: _qrPreview,
                                      version: QrVersions.auto,
                                      size: 180,
                                      errorCorrectionLevel:
                                          QrErrorCorrectLevel.M,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Output file name
                            TextFormField(
                              controller: _outFileNameC,
                              decoration: const InputDecoration(
                                labelText: 'Output File Name (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Opacity
                            Text(
                              'Opacity: ${(_opacity * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Slider(
                              min: 0.05,
                              max: 1.0,
                              divisions: 19,
                              value: _opacity,
                              onChanged: (v) => setState(() => _opacity = v),
                            ),
                            const SizedBox(height: 12),

                            // Page range
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _fromPageC,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'From Page (0-indexed)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _toPageC,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'To Page (optional)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _qrPreview.isNotEmpty && !_generating
                            ? _onStamp
                            : null,
                        icon: _generating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.qr_code_2),
                        label: const Text('Stamp QR Code on PDF'),
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

  Future<void> _onStamp() async {
    if (_qrPreview.isEmpty) return;
    setState(() => _generating = true);
    try {
      // Capture QR widget as PNG bytes
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('QR widget not rendered');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode QR image');

      // Write to temp file
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/qr_stamp_${DateTime.now().millisecondsSinceEpoch}.png');
      await tmpFile.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;

      BlocProvider.of<PdfBloc>(context).add(StampPdfEvent(
        stampPdf: StampPdf(
          outFileName: _outFileNameC.text.trim().isEmpty
              ? null
              : _outFileNameC.text.trim(),
          opacity: _opacity,
          fromPage: int.tryParse(_fromPageC.text) ?? 0,
          toPage: _toPageC.text.trim().isEmpty
              ? null
              : int.tryParse(_toPageC.text),
          file: await MultipartFile.fromFile(widget.file.path),
          stamp: await MultipartFile.fromFile(tmpFile.path,
              contentType: DioMediaType.parse('image/png')),
        ),
      ));
    } catch (e) {
      NotificationService.showSnackbar(
          text: 'Failed to generate QR: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  void dispose() {
    _qrDataC.dispose();
    _outFileNameC.dispose();
    _fromPageC.dispose();
    _toPageC.dispose();
    super.dispose();
  }
}
