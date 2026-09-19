import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/inspect_pdf.dart';
import 'package:pdf_craft/pages/inspector/inspector_scaffold.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// The whole document as structured JSON — metadata, per-page geometry, annotations, form values
/// and (optionally) the text.
///
/// Text extraction is the expensive half of the request on a large scan, so it is a switch rather
/// than something the user pays for silently. Toggling it remounts the scaffold, which re-fetches.
class PdfToJsonView extends StatefulWidget {
  final File file;
  const PdfToJsonView({super.key, required this.file});

  @override
  State<PdfToJsonView> createState() => _PdfToJsonViewState();
}

class _PdfToJsonViewState extends State<PdfToJsonView> {
  bool _includeText = true;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return InspectorScaffold(
      // The key carries the switch, so flipping it rebuilds the scaffold from scratch and its
      // initState issues a fresh request with the new query.
      key: ValueKey(_includeText),
      file: widget.file,
      title: ToolStrings.name(context, 'pdf-to-json'),
      stateKey: HttpStates.pdfToJson,
      buildEvent: (cancelToken, upload) => InspectPdfEvent(
        inspect: InspectPdf(file: upload, query: {'include-text': _includeText}),
        url: PdfService.pdfToJson,
        stateKey: HttpStates.pdfToJson,
        cancelToken: cancelToken,
      ),
      report: (context, theme, raw) => _build(context, theme, raw, l),
    );
  }

  Widget _build(BuildContext context, ThemeData theme, dynamic raw, AppLocalizations l) {
    final r = asReport(raw);
    if (r == null) return Center(child: Text(L10n.of(context).noAnalysisAvailable));
    final meta = (r['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pages = (r['pages'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: SwitchListTile(
            value: _includeText,
            onChanged: (v) => setState(() => _includeText = v),
            title: Text(l.inspIncludeText),
            subtitle: Text(l.inspIncludeTextHint, style: theme.textTheme.bodySmall),
          ),
        ),
        InspectorSection(
          title: l.inspMetadata,
          icon: Icons.info_outline,
          children: [
            InspectorRow(l.inspTitle, meta['title']?.toString()),
            InspectorRow(l.inspAuthor, meta['author']?.toString()),
            InspectorRow(l.inspSubject, meta['subject']?.toString()),
            InspectorRow(l.inspKeywords, meta['keywords']?.toString()),
            InspectorRow(l.inspCreator, meta['creator']?.toString()),
            InspectorRow(l.inspProducer, meta['producer']?.toString()),
            InspectorRow(l.inspPdfVersion, meta['pdfVersion']?.toString()),
          ],
        ),
        for (final p in pages)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(l.inspPageN(p['page'] ?? '?')),
              subtitle: Text('${p['widthPt']} × ${p['heightPt']} pt'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                InspectorRow(l.inspAnnotations, p['annotations']?.toString()),
                InspectorRow(l.inspImages, p['imageCount']?.toString()),
                InspectorRow(l.inspFonts, (p['fonts'] as List? ?? const []).join(', ')),
                if (p['text'] != null) ...[
                  const SizedBox(height: 8),
                  SelectableText('${p['text']}'.trim(),
                      style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
