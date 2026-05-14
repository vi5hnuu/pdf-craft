import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/remove-blank-pages.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class RemoveBlankPagesView extends StatefulWidget {
  final File file;
  const RemoveBlankPagesView({super.key, required this.file});

  @override
  State<RemoveBlankPagesView> createState() => _RemoveBlankPagesViewState();
}

class _RemoveBlankPagesViewState extends State<RemoveBlankPagesView> {
  // 0.85 = low sensitivity (only very blank), 0.98 = high sensitivity
  double _sensitivity = 0.95;

  String get _sensitivityLabel {
    if (_sensitivity >= 0.97) return 'High — removes lightly used pages';
    if (_sensitivity >= 0.92) return 'Medium — removes mostly blank pages';
    return 'Low — removes only fully blank pages';
  }

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(title: const Text('Remove Blank Pages')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.REMOVE_BLANK_PAGES] != c.httpStates[HttpStates.REMOVE_BLANK_PAGES],
        listenWhen: (p, c) => p.httpStates[HttpStates.REMOVE_BLANK_PAGES] != c.httpStates[HttpStates.REMOVE_BLANK_PAGES],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.REMOVE_BLANK_PAGES];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Blank pages removed', color: Colors.green);
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
          final loading = state.httpStates[HttpStates.REMOVE_BLANK_PAGES]?.loading == true;
          return Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                        style: theme.textTheme.bodySmall),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Detection Sensitivity', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Slider(
                  value: _sensitivity,
                  min: 0.85,
                  max: 0.99,
                  divisions: 14,
                  onChanged: (v) => setState(() => _sensitivity = v),
                ),
                Text(_sensitivityLabel,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _onApply,
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_sweep_outlined),
                    label: Text(loading ? 'Processing…' : 'Remove Blank Pages'),
                  ),
                ),
              ]),
            ),
            LoadingOverlay(httpState: state.httpStates[HttpStates.REMOVE_BLANK_PAGES]),
          ]);
        },
      ),
    );
  }

  Future<void> _onApply() async {
    BlocProvider.of<PdfBloc>(context).add(RemoveBlankPagesEvent(
      removeBlankPages: RemoveBlankPages(
        threshold: _sensitivity,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }
}
