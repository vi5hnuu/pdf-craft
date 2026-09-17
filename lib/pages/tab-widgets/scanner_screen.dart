import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/image_to_pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/full_screen_ad_policy.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/tools/credit_gate.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/utils/upload_limits.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/singletons/file_store.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:pdf_craft/widgets/loading_overlay.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  DocumentScanner? _documentScanner;
  DocumentScanningResult? _result;
  // Which scan card is busy (0 = Scan to PDF, 1 = JPEG), or null
  // when idle. Only the active card shows a spinner; the rest are just disabled.
  int? _scanningCard;
  bool get _busy => _scanningCard != null;
  final TextEditingController _outFileNameC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<PdfBloc, PdfState>(
      listenWhen: (p, c) =>
          p.httpStates[HttpStates.imageToPdf] != c.httpStates[HttpStates.imageToPdf],
      buildWhen: (p, c) =>
          p.httpStates[HttpStates.imageToPdf] != c.httpStates[HttpStates.imageToPdf],
      listener: (context, state) {
        final s = state.httpStates[HttpStates.imageToPdf];
        if (s?.done == true) {
          final savedFile = s?.extras?['savedFile'];
          NotificationService.showSnackbar(text: L10n.current.scanImagesMerged, color: Colors.green);
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
          LoadingOverlay(httpState: state.httpStates[HttpStates.imageToPdf], label: L10n.of(context).scanCreatingPdf),
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
          Text(L10n.of(context).scanTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            L10n.of(context).scanSubtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 32),
          // Two equal cards side by side. IntrinsicHeight keeps both the same height when one
          // description wraps to more lines than the other.
          //
          // A third "Searchable PDF (OCR)" card used to sit here, but it ran the exact same scan
          // as "Scan to PDF" — no text layer was ever produced — so it was removed rather than
          // promise a feature that does not exist.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ScanCard(
                    icon: Icons.picture_as_pdf,
                    label: L10n.of(context).scanToPdf,
                    description: L10n.of(context).scanToPdfDesc,
                    color: theme.colorScheme.primary,
                    loading: _scanningCard == 0,
                    enabled: !_busy,
                    onTap: () => _startScan(DocumentFormat.pdf, 0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ScanCard(
                    icon: Icons.image_outlined,
                    label: L10n.of(context).scanToJpeg,
                    description: L10n.of(context).scanToJpegDesc,
                    color: const Color(0xFF7B1FA2),
                    loading: _scanningCard == 1,
                    enabled: !_busy,
                    onTap: () => _startScan(DocumentFormat.jpeg, 1),
                  ),
                ),
              ],
            ),
          ),
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
                    L10n.of(context).scanTip,
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
              isPdf
                  ? L10n.of(context).scanPdfDocument
                  : L10n.of(context).scanImagesCount(_result!.images?.length ?? 0),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: L10n.of(context).discard,
            onPressed: () => setState(() => _result = null),
          ),
        ]),
      ),

      // Output filename
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextFormField(
          controller: _outFileNameC,
          decoration: InputDecoration(
            labelText: L10n.of(context).outputFileName,
            border: const OutlineInputBorder(),
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
          label: Text(isPdf ? L10n.of(context).scanSavePdf : L10n.of(context).scanMergeToPdf),
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
          borderRadius: BorderRadius.circular(AppRadius.surface),
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
                Text(L10n.of(context).scanPdfReady,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  L10n.of(context).scanTapToPreview,
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
                // Scanned pages come off the camera at full sensor resolution.
                cacheWidth: (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, __, ___) =>
                    const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image))),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(L10n.of(context).pageNumber(index + 1),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  Future<void> _startScan(DocumentFormat format, int card) async {
    if (_busy) return;
    setState(() => _scanningCard = card);
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
      // The scanner runs in its own activity; returning from it is not a resume worth an ad.
      final scanner = _documentScanner!;
      final result = await FullScreenAdPolicy().runExternal(() => scanner.scanDocument());
      // Scanning hands control to another activity and can take minutes, which is ample time
      // for this screen to be disposed before the result comes back.
      if (!mounted) return;
      AdsSingleton().dispatch(LoadInterstitialAd());
      setState(() {
        _result = result;
        _scanningCard = null;
      });
    } catch (_) {
      setState(() => _scanningCard = null);
      NotificationService.showSnackbar(text: L10n.current.scanCancelledOrFailed, color: Colors.red);
    }
  }

  Future<void> _saveResult(DocumentScanningResult result) async {
    final fileName = _outFileNameC.text.trim().isEmpty
        ? 'scanned-${DateTime.now().millisecondsSinceEpoch}'
        : _outFileNameC.text.trim();

    if (result.pdf != null) {
      await _savePdf(result.pdf!, fileName);
    } else {
      final images = (result.images ?? []).map((p) => File(p)).toList();
      // Merging scanned images runs on the server (the priced image-to-pdf tool). This path used
      // to spend credits without asking; it now checks size and confirms the cost exactly like
      // opening Image to PDF from the Tools tab.
      if (!await UploadLimits.ensureWithinLimits(context, images)) return;
      if (!mounted) return;
      final bloc = BlocProvider.of<PdfBloc>(context);
      await CreditGate.run(
        context,
        creditToolId: ToolRegistry.byId('image-to-pdf')?.creditToolId,
        toolName: L10n.current.scanMergeToPdf,
        files: images,
        proceed: () async {
          bloc.add(ImageToPdfEvent(
            imageToPdf: ImageToPdf(
              outFileName: fileName,
              files: await Future.wait(images.map((f) => MultipartFile.fromFile(f.path))),
            ),
          ));
        },
      );
    }
  }

  Future<void> _savePdf(DocumentScanningResultPdf pdf, String fileName) async {
    final router = GoRouter.of(context);
    try {
      final rootDir = Directory(Constants.processedDirPath);
      if (!await rootDir.exists()) await rootDir.create(recursive: true);
      final source = File.fromUri(Uri.file(pdf.uri));
      final target = await source.copy('${Constants.processedDirPath}/$fileName.pdf');
      FileStore().changed();
      if (!mounted) return;
      setState(() => _result = null);
      NotificationService.showSnackbar(text: L10n.current.savedTo(target.path), color: Colors.green);
      router.pushNamed(
        AppRoutes.pdfFilePreviewRoute.name,
        pathParameters: {'pdfFilePath': target.path},
      );
    } catch (e) {
      NotificationService.showSnackbar(text: L10n.current.failedToSave('$e'), color: Colors.red);
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
  final bool enabled;
  final VoidCallback onTap;

  const _ScanCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.loading,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      // Dim the non-active cards while a scan is running.
      opacity: (enabled || loading) ? 1 : 0.5,
      child: Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.surface),
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
      ),
    );
  }
}
