import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/sanitize-pdf.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Sanitize PDF: removes active/unsafe content — JavaScript, embedded files,
/// document actions and metadata — while leaving the visible pages intact.
class SanitizePdfView extends StatefulWidget {
  final File file;
  const SanitizePdfView({super.key, required this.file});

  @override
  State<SanitizePdfView> createState() => _SanitizePdfViewState();
}

class _SanitizePdfViewState extends State<SanitizePdfView>
    with ToolResultHandler, ToolViewMixin {
  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.SANITIZE_PDF]);
  }

  static const _removed = [
    ('JavaScript', Icons.code_off),
    ('Embedded / attached files', Icons.attach_file),
    ('Open & event actions', Icons.bolt_outlined),
    ('Document metadata', Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sanitize PDF')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.SANITIZE_PDF] != c.httpStates[HttpStates.SANITIZE_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.SANITIZE_PDF] != c.httpStates[HttpStates.SANITIZE_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.SANITIZE_PDF], successMessage: 'PDF sanitized'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.SANITIZE_PDF]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.security_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Remove active and unsafe content before sharing.',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text('This will strip:',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(children: [
                        for (int i = 0; i < _removed.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 52),
                          ListTile(
                            dense: true,
                            leading: Icon(_removed[i].$2, size: 20, color: theme.colorScheme.primary),
                            title: Text(_removed[i].$1),
                            trailing: const Icon(Icons.close, size: 16, color: Colors.red),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text('The visible page content is unchanged.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                  ]),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: FilledButton.icon(
                  onPressed: loading ? null : _onSanitize,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Sanitize PDF'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.SANITIZE_PDF], label: 'Sanitizing your PDF'),
          ]);
        },
      ),
    );
  }

  Future<void> _onSanitize() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => SanitizePdfEvent(
          sanitizePdf: SanitizePdf(file: file),
          cancelToken: cancelToken,
        ));
  }
}
