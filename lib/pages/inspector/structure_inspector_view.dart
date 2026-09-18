import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/inspect_pdf.dart';
import 'package:pdf_craft/pages/inspector/inspector_scaffold.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// The document's skeleton: catalog flags, then one expandable row per page carrying its size,
/// rotation, fonts and resource counts.
class StructureInspectorView extends StatelessWidget {
  final File file;
  const StructureInspectorView({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return InspectorScaffold(
      file: file,
      title: ToolStrings.name(context, 'structure-inspector'),
      stateKey: HttpStates.inspectStructure,
      buildEvent: (cancelToken, upload) => InspectPdfEvent(
        inspect: InspectPdf(file: upload),
        url: PdfService.inspectStructure,
        stateKey: HttpStates.inspectStructure,
        cancelToken: cancelToken,
      ),
      report: _build,
    );
  }

  Widget _build(BuildContext context, ThemeData theme, dynamic raw) {
    final l = L10n.of(context);
    final r = (raw as Map).cast<String, dynamic>();
    final info = (r['info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pages = (r['pages'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        InspectorSection(
          title: l.inspDocument,
          icon: Icons.account_tree_outlined,
          children: [
            InspectorRow(l.inspPdfVersion, r['pdfVersion']?.toString()),
            InspectorRow(l.inspPages, r['pageCount']?.toString()),
            InspectorRow(l.inspPageLayout, r['pageLayout']?.toString()),
            InspectorRow(l.inspPageMode, r['pageMode']?.toString()),
            InspectorRow(l.inspLanguage, r['language']?.toString()),
            InspectorFlag(l.inspHasOutline, r['hasOutline'] == true),
            InspectorFlag(l.inspHasAcroForm, r['hasAcroForm'] == true),
            InspectorFlag(l.inspHasStructureTree, r['hasStructureTree'] == true),
            InspectorFlag(l.inspHasXmp, r['hasXmpMetadata'] == true),
          ],
        ),
        InspectorSection(
          title: l.inspMetadata,
          icon: Icons.info_outline,
          children: [
            InspectorRow(l.inspTitle, info['title']?.toString()),
            InspectorRow(l.inspAuthor, info['author']?.toString()),
            InspectorRow(l.inspCreator, info['creator']?.toString()),
            InspectorRow(l.inspProducer, info['producer']?.toString()),
          ],
        ),
        // One tile per page rather than a flat list of everything: a 400-page document would
        // otherwise be several thousand rows.
        for (final p in pages)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(Icons.insert_drive_file_outlined,
                  color: theme.colorScheme.primary),
              title: Text(l.inspPageN(p['page'] ?? '?')),
              subtitle: Text('${p['widthPt']} × ${p['heightPt']} pt'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                InspectorRow(l.inspRotation, '${p['rotation'] ?? 0}°'),
                InspectorRow(l.inspAnnotations, p['annotations']?.toString()),
                InspectorRow(l.inspImages, p['imageCount']?.toString()),
                InspectorRow(l.inspFormXObjects, p['formXObjectCount']?.toString()),
                InspectorRow(
                    l.inspFonts, (p['fonts'] as List? ?? const []).join(', ')),
              ],
            ),
          ),
      ],
    );
  }
}
