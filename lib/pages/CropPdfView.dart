import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/crop-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:pdfx/pdfx.dart';

class CropPdfView extends StatefulWidget {
  final File file;
  const CropPdfView({super.key, required this.file});

  @override
  State<CropPdfView> createState() => _CropPdfViewState();
}

class _CropPdfViewState extends State<CropPdfView> {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();

  PdfPageImage? _pageImage;
  double _pageWidthPt = 595.0;  // fallback A4
  double _pageHeightPt = 842.0;

  // Crop fractions: 0.0 = no crop on that edge, up to 0.9 max
  double _cropTop = 0.0;
  double _cropBottom = 0.0;
  double _cropLeft = 0.0;
  double _cropRight = 0.0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final page = await doc.getPage(1);
      _pageWidthPt = page.width;
      _pageHeightPt = page.height;
      final img = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      await doc.close();
      if (!mounted) return;
      setState(() {
        _pageImage = img;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Margin values in PDF points, computed from fractions × page dimension
  double get _marginTopPt => _cropTop * _pageHeightPt;
  double get _marginBottomPt => _cropBottom * _pageHeightPt;
  double get _marginLeftPt => _cropLeft * _pageWidthPt;
  double get _marginRightPt => _cropRight * _pageWidthPt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crop PDF')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.CROP_PDF] != c.httpStates[HttpStates.CROP_PDF],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.CROP_PDF] != c.httpStates[HttpStates.CROP_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.CROP_PDF];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(
                text: 'PDF cropped successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,
                  pathParameters: {
                    'pdfFilePath': (s!.extras!['savedFile'] as File).path
                  });
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(
                text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(
                text: 'Cropping PDF…', color: Colors.lightBlue);
          }
        },
        builder: (context, state) {
          return Stack(children: [
            Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _outFileNameC,
                        decoration: const InputDecoration(
                          labelText: 'Output File Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Drag handles to set crop margins',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Blue shaded area will be removed. Drag the handles inward.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55)),
                      ),
                      const SizedBox(height: 12),

                      // Visual crop canvas
                      _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _buildCropCanvas(theme),

                      const SizedBox(height: 16),
                      // Numeric readout
                      _buildMarginReadout(theme),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton(
                  onPressed: _onCrop,
                  child: const Text('Crop PDF'),
                ),
              ),
            ]),
            LoadingOverlay(httpState: state.httpStates[HttpStates.CROP_PDF]),
          ]);
        },
      ),
    );
  }

  Widget _buildCropCanvas(ThemeData theme) {
    return LayoutBuilder(builder: (context, constraints) {
      final canvasW = constraints.maxWidth;
      // Maintain page aspect ratio in the canvas
      final canvasH = canvasW * (_pageHeightPt / _pageWidthPt);
      final cropColor = theme.colorScheme.primary.withValues(alpha: 0.25);
      const handleColor = Colors.blue;
      const handleThickness = 3.0;
      const handleHitArea = 32.0;

      return SizedBox(
        width: canvasW,
        height: canvasH,
        child: Stack(children: [
          // Page image
          Positioned.fill(
            child: _pageImage != null
                ? Image.memory(_pageImage!.bytes, fit: BoxFit.fill)
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.picture_as_pdf, size: 64)),
                  ),
          ),

          // Top crop overlay
          Positioned(
            top: 0, left: 0, right: 0,
            height: _cropTop * canvasH,
            child: Container(color: cropColor),
          ),
          // Bottom crop overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: _cropBottom * canvasH,
            child: Container(color: cropColor),
          ),
          // Left crop overlay
          Positioned(
            top: 0, bottom: 0, left: 0,
            width: _cropLeft * canvasW,
            child: Container(color: cropColor),
          ),
          // Right crop overlay
          Positioned(
            top: 0, bottom: 0, right: 0,
            width: _cropRight * canvasW,
            child: Container(color: cropColor),
          ),

          // Top handle — draggable horizontal line
          Positioned(
            top: (_cropTop * canvasH) - (handleHitArea / 2),
            left: 0, right: 0, height: handleHitArea,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                setState(() {
                  _cropTop = (_cropTop + d.delta.dy / canvasH)
                      .clamp(0.0, 0.9 - _cropBottom);
                });
              },
              child: Stack(children: [
                Positioned(
                  top: (handleHitArea - handleThickness) / 2,
                  left: 0, right: 0, height: handleThickness,
                  child: Container(color: handleColor),
                ),
                Center(child: _handleKnob()),
              ]),
            ),
          ),

          // Bottom handle
          Positioned(
            bottom: (_cropBottom * canvasH) - (handleHitArea / 2),
            left: 0, right: 0, height: handleHitArea,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                setState(() {
                  _cropBottom = (_cropBottom - d.delta.dy / canvasH)
                      .clamp(0.0, 0.9 - _cropTop);
                });
              },
              child: Stack(children: [
                Positioned(
                  top: (handleHitArea - handleThickness) / 2,
                  left: 0, right: 0, height: handleThickness,
                  child: Container(color: handleColor),
                ),
                Center(child: _handleKnob()),
              ]),
            ),
          ),

          // Left handle
          Positioned(
            left: (_cropLeft * canvasW) - (handleHitArea / 2),
            top: 0, bottom: 0, width: handleHitArea,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                setState(() {
                  _cropLeft = (_cropLeft + d.delta.dx / canvasW)
                      .clamp(0.0, 0.9 - _cropRight);
                });
              },
              child: Stack(children: [
                Positioned(
                  left: (handleHitArea - handleThickness) / 2,
                  top: 0, bottom: 0, width: handleThickness,
                  child: Container(color: handleColor),
                ),
                Center(child: _handleKnob()),
              ]),
            ),
          ),

          // Right handle
          Positioned(
            right: (_cropRight * canvasW) - (handleHitArea / 2),
            top: 0, bottom: 0, width: handleHitArea,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                setState(() {
                  _cropRight = (_cropRight - d.delta.dx / canvasW)
                      .clamp(0.0, 0.9 - _cropLeft);
                });
              },
              child: Stack(children: [
                Positioned(
                  left: (handleHitArea - handleThickness) / 2,
                  top: 0, bottom: 0, width: handleThickness,
                  child: Container(color: handleColor),
                ),
                Center(child: _handleKnob()),
              ]),
            ),
          ),
        ]),
      );
    });
  }

  Widget _handleKnob() => Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: const Icon(Icons.drag_handle, color: Colors.white, size: 14),
      );

  Widget _buildMarginReadout(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _margin('Top', _marginTopPt),
            _margin('Bottom', _marginBottomPt),
            _margin('Left', _marginLeftPt),
            _margin('Right', _marginRightPt),
          ],
        ),
      ),
    );
  }

  Widget _margin(String label, double pt) => Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text('${pt.toStringAsFixed(0)} pt',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );

  void _onCrop() async {
    bloc.add(CropPdfEvent(
      cropPdf: CropPdf(
        outFileName: _outFileNameC.text.trim().isEmpty
            ? 'cropped_file'
            : _outFileNameC.text.trim(),
        marginTop: _marginTopPt,
        marginBottom: _marginBottomPt,
        marginLeft: _marginLeftPt,
        marginRight: _marginRightPt,
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
