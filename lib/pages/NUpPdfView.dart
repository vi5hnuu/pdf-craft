import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/n-up.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class NUpPdfView extends StatefulWidget {
  final File file;
  const NUpPdfView({super.key, required this.file});

  @override
  State<NUpPdfView> createState() => _NUpPdfViewState();
}

class _NUpPdfViewState extends State<NUpPdfView> {
  int _nUp = 2;
  // Read once (off the build path) so rebuilds don't re-stat the file.
  String _sizeLabel = '';

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    try {
      _sizeLabel = '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB';
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(title: const Text('N-Up Layout')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.N_UP_PDF] != c.httpStates[HttpStates.N_UP_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.N_UP_PDF] != c.httpStates[HttpStates.N_UP_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.N_UP_PDF];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'N-up PDF created', color: Colors.green);
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
          final loading = state.httpStates[HttpStates.N_UP_PDF]?.loading == true;
          return Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_sizeLabel, style: theme.textTheme.bodySmall),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Pages per Sheet', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  _layoutOption(theme, 2, '2-Up', 'Landscape, side by side', Icons.view_agenda_outlined),
                  const SizedBox(width: 12),
                  _layoutOption(theme, 4, '4-Up', 'Portrait, 2×2 grid', Icons.grid_view_outlined),
                ]),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _onApply,
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.view_module_outlined),
                    label: Text(loading ? 'Processing…' : 'Create $_nUp-Up PDF'),
                  ),
                ),
              ]),
            ),
            LoadingOverlay(httpState: state.httpStates[HttpStates.N_UP_PDF], label: 'Building N-up layout'),
          ]);
        },
      ),
    );
  }

  Widget _layoutOption(ThemeData theme, int n, String title, String subtitle, IconData icon) {
    final selected = _nUp == n;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _nUp = n),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primaryContainer : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            // On a primaryContainer surface the correct foreground is
            // onPrimaryContainer — using `primary` here made the icon wash out.
            Icon(icon,
                color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                size: 32),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? theme.colorScheme.onPrimaryContainer : null,
            )),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  Future<void> _onApply() async {
    final baseName = widget.file.path.split('/').last.replaceAll('.pdf', '');
    BlocProvider.of<PdfBloc>(context).add(NUpPdfEvent(
      nUp: NUp(
        nUp: _nUp,
        outFileName: '${baseName}_${_nUp}up',
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }
}
