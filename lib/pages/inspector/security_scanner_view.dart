import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/inspect_pdf.dart';
import 'package:pdf_craft/pages/inspector/inspector_scaffold.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// Reports the active and privacy-relevant content in a PDF: scripts, automatic actions,
/// attachments, outbound links, forms and signatures.
///
/// Deliberately worded as "what is in here", never as "this file is malicious". A PDF with
/// JavaScript is usually a form; the value is in knowing before you forward it.
class SecurityScannerView extends StatelessWidget {
  final File file;
  const SecurityScannerView({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return InspectorScaffold(
      file: file,
      title: ToolStrings.name(context, 'security-scanner'),
      stateKey: HttpStates.scanSecurity,
      buildEvent: (cancelToken, upload) => InspectPdfEvent(
        inspect: InspectPdf(file: upload),
        url: PdfService.scanSecurity,
        stateKey: HttpStates.scanSecurity,
        cancelToken: cancelToken,
      ),
      report: _build,
    );
  }

  /// The backend's finding ids mapped to translated labels. An unknown id falls back to the
  /// server's own English detail rather than showing a raw identifier.
  String _label(AppLocalizations l, String id) => switch (id) {
        'javascript' => l.inspFindingJavascript,
        'openAction' => l.inspFindingOpenAction,
        'additionalActions' => l.inspFindingAdditionalActions,
        'embeddedFiles' => l.inspFindingEmbeddedFiles,
        'externalLinks' => l.inspFindingExternalLinks,
        'acroForm' => l.inspFindingAcroForm,
        'xfa' => l.inspFindingXfa,
        'signatures' => l.inspFindingSignatures,
        'encrypted' => l.inspFindingEncrypted,
        'annotations' => l.inspFindingAnnotations,
        _ => id,
      };

  Widget _build(BuildContext context, ThemeData theme, dynamic raw) {
    final l = L10n.of(context);
    final r = asReport(raw);
    if (r == null) return Center(child: Text(L10n.of(context).noAnalysisAvailable));
    final risk = r['riskLevel']?.toString() ?? 'clean';
    final findings = (r['findings'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final uris = (r['externalUris'] as List? ?? const []).map((e) => '$e').toList();
    final embedded = (r['embeddedFiles'] as List? ?? const []).map((e) => '$e').toList();

    final riskColor = SeverityChip.colorFor(risk);
    final riskText = switch (risk) {
      'high' => l.inspRiskHigh,
      'medium' => l.inspRiskMedium,
      'low' => l.inspRiskLow,
      _ => l.inspRiskClean,
    };

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: riskColor.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(risk == 'clean' ? Icons.verified_outlined : Icons.shield_outlined,
                  size: 32, color: riskColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(riskText,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: riskColor, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
        if (findings.isNotEmpty)
          InspectorSection(
            title: l.inspFindings,
            icon: Icons.policy_outlined,
            children: [
              for (final f in findings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SeverityChip('${f['severity']}', '${f['severity']}'.toUpperCase()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_label(l, '${f['id']}'),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text('${f['detail'] ?? ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        if (embedded.isNotEmpty)
          InspectorSection(
            title: l.inspEmbeddedFiles,
            icon: Icons.attachment_outlined,
            children: [for (final e in embedded) InspectorRow('•', e)],
          ),
        if (uris.isNotEmpty)
          InspectorSection(
            title: l.inspExternalLinks,
            icon: Icons.link,
            // Shown as plain selectable text, never as a tappable link: the point of the tool is
            // to let someone read a destination they have reason not to trust.
            children: [for (final u in uris) InspectorRow('•', u)],
          ),
      ],
    );
  }
}
