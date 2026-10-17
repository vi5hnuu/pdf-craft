import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf_craft/theme/app_spacing.dart';
import 'package:pdf_craft/widgets/tool_pane.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
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
      appBar: AppBar(title: Text(ToolStrings.name(context, 'qr-stamp'))),
      // Scrolling content above a sticky action bar. This was a bare Padding > Column holding
      // a text field, a 224dp preview and a Spacer that can only shrink to zero — about 400dp
      // of fixed content against the ~290dp left once the keyboard is up, so focusing the URL
      // field was a hard overflow on any phone.
      body: ToolPane(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _qrDataC,
                      decoration: InputDecoration(
                        labelText: L10n.of(context).qrUrlLabel,
                        hintText: 'https://example.com',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_qrPreview.isNotEmpty) ...[
                      Text(L10n.of(context).preview,
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Center(
                        child: RepaintBoundary(
                          key: _qrKey,
                          // Deliberately white: a QR code needs its quiet zone, whatever the
                          // theme.
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
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ] else
                      // A fixed block rather than an Expanded, which a scroll view cannot
                      // give an unbounded child.
                      SizedBox(
                        height: 220,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_2,
                                  size: 80, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 12),
                              // onSurfaceVariant, not outlineVariant: this text explains why
                              // the button below is dead, so it was the lowest-emphasis role
                              // in the scheme carrying the screen's most important sentence.
                              Text(
                                L10n.of(context).qrEmptyHint,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _qrPreview.isNotEmpty && !_capturing ? _onPositionQr : null,
                  icon: _capturing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: theme.colorScheme.onPrimary))
                      : const Icon(Icons.place),
                  label: Text(L10n.of(context).positionQrOnPdf),
                ),
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
          'title': L10n.of(context).placeQrCode,
        },
      );
    } catch (e) {
      NotificationService.showSnackbar(text: L10n.current.failedWith('$e'), kind: SnackKind.error);
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
