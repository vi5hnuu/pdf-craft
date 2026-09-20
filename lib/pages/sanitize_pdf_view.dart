import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/sanitize_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

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
  // Sanitize used to be all-or-nothing: the screen listed what it would remove and offered one
  // button. Someone who wanted the author's name off a CV also lost the form they had filled in.
  // The first four default on — that is exactly the old behaviour — and the last three default
  // off because, unlike the rest, they visibly change the document.
  bool _javaScript = true;
  bool _embeddedFiles = true;
  bool _actions = true;
  bool _metadata = true;
  bool _annotations = false;
  bool _externalLinks = false;
  bool _forms = false;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.sanitizePdf]);
  }

  bool get _nothingSelected =>
      !_javaScript &&
      !_embeddedFiles &&
      !_actions &&
      !_metadata &&
      !_annotations &&
      !_externalLinks &&
      !_forms;

  /// One switch row. [destructive] marks the options that change how the document looks, so the
  /// user is not surprised by comments or links disappearing.
  Widget _option(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool destructive = false,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon,
          color: destructive ? Colors.orange.shade700 : theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'sanitize'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.sanitizePdf] != c.httpStates[HttpStates.sanitizePdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.sanitizePdf] != c.httpStates[HttpStates.sanitizePdf],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.sanitizePdf], successMessage: L10n.of(context).pdfSanitized),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.sanitizePdf]?.loading == true;
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
                    Text(l.sanitizeWhatToRemove,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(children: [
                        _option(theme,
                            title: l.sanitizeJavaScript,
                            subtitle: l.sanitizeJavaScriptSub,
                            icon: Icons.code_off,
                            value: _javaScript,
                            onChanged: (v) => setState(() => _javaScript = v)),
                        const Divider(height: 1, indent: 52),
                        _option(theme,
                            title: l.sanitizeEmbeddedFiles,
                            subtitle: l.sanitizeEmbeddedFilesSub,
                            icon: Icons.attach_file,
                            value: _embeddedFiles,
                            onChanged: (v) => setState(() => _embeddedFiles = v)),
                        const Divider(height: 1, indent: 52),
                        _option(theme,
                            title: l.sanitizeActions,
                            subtitle: l.sanitizeActionsSub,
                            icon: Icons.bolt_outlined,
                            value: _actions,
                            onChanged: (v) => setState(() => _actions = v)),
                        const Divider(height: 1, indent: 52),
                        _option(theme,
                            title: l.sanitizeMetadata,
                            subtitle: l.sanitizeMetadataSub,
                            icon: Icons.info_outline,
                            value: _metadata,
                            onChanged: (v) => setState(() => _metadata = v)),
                        const Divider(height: 1, indent: 52),
                        _option(theme,
                            title: l.sanitizeExternalLinks,
                            subtitle: l.sanitizeExternalLinksSub,
                            icon: Icons.link_off,
                            value: _externalLinks,
                            destructive: true,
                            onChanged: (v) => setState(() => _externalLinks = v)),
                        const Divider(height: 1, indent: 52),
                        _option(theme,
                            title: l.sanitizeAnnotations,
                            subtitle: l.sanitizeAnnotationsSub,
                            icon: Icons.comment_outlined,
                            value: _annotations,
                            destructive: true,
                            onChanged: (v) => setState(() => _annotations = v)),
                        const Divider(height: 1, indent: 52),
                        _option(theme,
                            title: l.sanitizeForms,
                            subtitle: l.sanitizeFormsSub,
                            icon: Icons.ballot_outlined,
                            value: _forms,
                            destructive: true,
                            onChanged: (v) => setState(() => _forms = v)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text(l.sanitizeUnchanged,
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
                  // Disabled with nothing ticked: sending that would upload the file, charge a
                  // round trip and hand back a byte-identical copy.
                  onPressed: (loading || _nothingSelected) ? null : _onSanitize,
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(ToolStrings.name(context, 'sanitize')),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.sanitizePdf], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Future<void> _onSanitize() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => SanitizePdfEvent(
          sanitizePdf: SanitizePdf(
            file: file,
            javaScript: _javaScript,
            embeddedFiles: _embeddedFiles,
            actions: _actions,
            metadata: _metadata,
            annotations: _annotations,
            externalLinks: _externalLinks,
            forms: _forms,
          ),
          cancelToken: cancelToken,
        ));
  }
}
