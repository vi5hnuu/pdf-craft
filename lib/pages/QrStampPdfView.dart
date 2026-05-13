import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR Code Stamp: user enters text/URL, sees a live QR preview, then positions
/// the QR on the PDF using the shared PlaceImageView canvas.
class QrStampPdfView extends StatefulWidget {
  final File file;
  const QrStampPdfView({super.key, required this.file});

  @override
  State<QrStampPdfView> createState() => _QrStampPdfViewState();
}

class _QrStampPdfViewState extends State<QrStampPdfView> {
  final _qrDataC = TextEditingController();
  final _qrKey = GlobalKey();

  String _qrPreview = '';
  bool _capturing = false;

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
      body: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 24),

            // Live QR preview
            if (_qrPreview.isNotEmpty) ...[
              Text('Preview', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
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
                      size: 200,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _qrPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2, size: 80, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text(
                        'Enter a URL or text above\nto generate a QR code',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Next step: position on PDF
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _qrPreview.isNotEmpty && !_capturing ? _onPositionQr : null,
                icon: _capturing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.place),
                label: const Text('Position QR on PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Captures the QR preview widget as PNG bytes then navigates to PlaceImageView.
  Future<void> _onPositionQr() async {
    if (_qrPreview.isEmpty) return;
    setState(() => _capturing = true);
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('QR widget not rendered yet');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode QR image');

      final qrBytes = byteData.buffer.asUint8List();

      if (!mounted) return;

      GoRouter.of(context).pushNamed(
        AppRoutes.placeImageRoute.name,
        extra: {
          'file': widget.file,
          'imageBytes': qrBytes,
          'title': 'Place QR Code',
        },
      );
    } catch (e) {
      NotificationService.showSnackbar(text: 'Failed: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _qrDataC.dispose();
    super.dispose();
  }
}
