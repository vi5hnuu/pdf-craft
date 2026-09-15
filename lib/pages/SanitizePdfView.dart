import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/models/request/sanitize-pdf.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
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

  /// Localized at build time, so the list follows the app language.
  List<(String, IconData)> _removedItems(BuildContext context) => [
    (L10n.of(context).sanJavascript, Icons.code_off),
    (L10n.of(context).sanEmbeddedFiles, Icons.attach_file),
    (L10n.of(context).sanActions, Icons.bolt_outlined),
    (L10n.of(context).sanMetadata, Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final removed = _removedItems(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'sanitize'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.SANITIZE_PDF] != c.httpStates[HttpStates.SANITIZE_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.SANITIZE_PDF] != c.httpStates[HttpStates.SANITIZE_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.SANITIZE_PDF], successMessage: L10n.of(context).pdfSanitized),
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
                        child: Text(L10n.of(context).sanitizeIntro,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text(L10n.of(context).sanitizeWillStrip,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(children: [
                        for (int i = 0; i < removed.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 52),
                          ListTile(
                            dense: true,
                            leading: Icon(removed[i].$2, size: 20, color: theme.colorScheme.primary),
                            title: Text(removed[i].$1),
                            trailing: const Icon(Icons.close, size: 16, color: Colors.red),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text(L10n.of(context).sanitizeUnchanged,
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
                  label: Text(ToolStrings.name(context, 'sanitize')),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.SANITIZE_PDF], label: L10n.of(context).procWorking),
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
