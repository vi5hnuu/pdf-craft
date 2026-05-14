import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/optimize-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class OptimizePdfView extends StatefulWidget {
  final File file;
  const OptimizePdfView({super.key, required this.file});

  @override
  State<OptimizePdfView> createState() => _OptimizePdfViewState();
}

class _OptimizePdfViewState extends State<OptimizePdfView> {
  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.file.path.split('/').last;
    final sizeKb = (widget.file.lengthSync() / 1024).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Optimize PDF')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.OPTIMIZE_PDF] != c.httpStates[HttpStates.OPTIMIZE_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.OPTIMIZE_PDF] != c.httpStates[HttpStates.OPTIMIZE_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.OPTIMIZE_PDF];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'PDF optimized', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(
                AppRoutes.pdfFilePreviewRoute.name,
                pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path},
              );
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.OPTIMIZE_PDF]?.loading == true;
          return Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('$sizeKb KB', style: theme.textTheme.bodySmall),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('What this does', style: theme.textTheme.titleSmall),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '• Removes embedded page thumbnails\n'
                        '• Re-compresses document streams\n'
                        '• Reduces file size without quality loss',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                      ),
                    ]),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _onApply,
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_fix_high),
                    label: Text(loading ? 'Optimizing…' : 'Optimize PDF'),
                  ),
                ),
              ]),
            ),
            LoadingOverlay(httpState: state.httpStates[HttpStates.OPTIMIZE_PDF]),
          ]);
        },
      ),
    );
  }

  Future<void> _onApply() async {
    final baseName = widget.file.path.split('/').last.replaceAll('.pdf', '');
    BlocProvider.of<PdfBloc>(context).add(OptimizePdfEvent(
      optimizePdf: OptimizePdf(
        outFileName: '${baseName}_optimized',
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }
}
