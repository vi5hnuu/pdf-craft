import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class ScannerScreen extends StatefulWidget {
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  DocumentScanner? _documentScanner;
  DocumentScanningResult? _result;
  bool _scanning = false;
  final TextEditingController _outFileNameC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<PdfBloc, PdfState>(
      listenWhen: (p, c) =>
          p.httpStates[HttpStates.IMAGE_TO_PDF] != c.httpStates[HttpStates.IMAGE_TO_PDF],
      buildWhen: (p, c) =>
          p.httpStates[HttpStates.IMAGE_TO_PDF] != c.httpStates[HttpStates.IMAGE_TO_PDF],
      listener: (context, state) {
        final s = state.httpStates[HttpStates.IMAGE_TO_PDF];
        if (s?.done == true) {
          final savedFile = s?.extras?['savedFile'];
          NotificationService.showSnackbar(text: 'Images merged to PDF', color: Colors.green);
          if (savedFile is File) {
            OpenFile.open(
              savedFile.path,
              type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(savedFile)] ?? '*/*',
            );
          }
          setState(() => _result = null);
        } else if (s?.error != null) {
          NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
        }
      },
      builder: (context, state) {
        return Stack(children: [
          SafeArea(
            child: Column(children: [
              Expanded(
                child: _result == null
                    ? _buildScanOptions(theme)
                    : _buildResult(theme, state),
              ),
              const BannerAdd(),
            ]),
          ),
          LoadingOverlay(httpState: state.httpStates[HttpStates.IMAGE_TO_PDF]),
        ]);
      },
    );
  }

  // ── Scan options ──────────────────────────────────────────────────────────

  Widget _buildScanOptions(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Document Scanner',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Scan physical documents with your camera or import from gallery.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: _ScanCard(
              icon: Icons.picture_as_pdf,
              label: 'Scan to PDF',
              description: 'Creates a multi-page PDF from scanned pages.',
              color: theme.colorScheme.primary,
              loading: _scanning,
              onTap: () => _startScan(DocumentFormat.pdf),
            )),
            const SizedBox(width: 16),
            Expanded(child: _ScanCard(
              icon: Icons.image_outlined,
              label: 'Scan to JPEG',
              description: 'Saves each page as a separate JPEG image.',
              color: const Color(0xFF7B1FA2),
              loading: _scanning,
              onTap: () => _startScan(DocumentFormat.jpeg),
            )),
          ]),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.info_outline,
                    size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: You can import from your gallery as well as scan with the camera.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Result view ───────────────────────────────────────────────────────────

  Widget _buildResult(ThemeData theme, PdfState state) {
    final isPdf = _result!.pdf != null;
    return Column(children: [
      // Header bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(children: [
          Icon(isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
              color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPdf ? 'Scanned PDF Document' : '${_result!.images?.length ?? 0} Scanned Image(s)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Discard',
            onPressed: () => setState(() => _result = null),
          ),
        ]),
      ),

      // Output filename
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextFormField(
          controller: _outFileNameC,
          decoration: const InputDecoration(
            labelText: 'Output File Name',
            border: OutlineInputBorder(),
          ),
        ),
      ),

      // Preview area
      Expanded(
        child: isPdf
            ? _buildPdfPreviewTile(theme)
            : _buildImagesList(),
      ),

      // Action bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: FilledButton.icon(
          onPressed: () => _saveResult(_result!),
          icon: const Icon(Icons.save_alt),
          label: Text(isPdf ? 'Save PDF' : 'Merge to PDF'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
        ),
      ),
    ]);
  }

  Widget _buildPdfPreviewTile(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Open the scanned PDF
            final uri = _result!.pdf!.uri;
            OpenFile.open(uri, type: 'application/pdf');
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Scanned PDF ready',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Tap to preview • Press "Save PDF" to save',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagesList() {
    final images = _result?.images ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.file(
                File(images[index]),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image))),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Page ${index + 1}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  Future<void> _startScan(DocumentFormat format) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      _documentScanner?.close();
      _documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {format},
          mode: ScannerMode.full,
          isGalleryImport: true,
          pageLimit: 10,
        ),
      );
      final result = await _documentScanner?.scanDocument();
      AdsSingleton().dispatch(LoadInterstitialAd());
      setState(() {
        _result = result;
        _scanning = false;
      });
    } catch (_) {
      setState(() => _scanning = false);
      NotificationService.showSnackbar(text: 'Scan cancelled or failed', color: Colors.red);
    }
  }

  Future<void> _saveResult(DocumentScanningResult result) async {
    final fileName = _outFileNameC.text.trim().isEmpty
        ? 'scanned-${DateTime.now().millisecondsSinceEpoch}'
        : _outFileNameC.text.trim();

    if (result.pdf != null) {
      await _savePdf(result.pdf!, fileName);
    } else {
      BlocProvider.of<PdfBloc>(context).add(ImageToPdfEvent(
        imageToPdf: ImageToPdf(
          out_file_name: fileName,
          files: await Future.wait(
            (result.images ?? []).map((p) => MultipartFile.fromFile(p)),
          ),
        ),
      ));
    }
  }

  Future<void> _savePdf(DocumentScanningResultPdf pdf, String fileName) async {
    final router = GoRouter.of(context);
    try {
      final rootDir = Directory(Constants.processedDirPath);
      if (!await rootDir.exists()) await rootDir.create(recursive: true);
      final source = File.fromUri(Uri.file(pdf.uri));
      final target = await source.copy('${Constants.processedDirPath}/$fileName.pdf');
      if (!mounted) return;
      setState(() => _result = null);
      NotificationService.showSnackbar(text: 'Saved to ${target.path}', color: Colors.green);
      router.pushNamed(
        AppRoutes.pdfFilePreviewRoute.name,
        pathParameters: {'pdfFilePath': target.path},
      );
    } catch (e) {
      NotificationService.showSnackbar(text: 'Failed to save: $e', color: Colors.red);
    }
  }

  @override
  void dispose() {
    _documentScanner?.close();
    _outFileNameC.dispose();
    super.dispose();
  }
}

// ── Scan option card ──────────────────────────────────────────────────────────

class _ScanCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ScanCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: loading
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
                      )
                    : Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 14),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
