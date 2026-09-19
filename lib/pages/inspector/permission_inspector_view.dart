import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/inspect_pdf.dart';
import 'package:pdf_craft/pages/inspector/inspector_scaffold.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// What the PDF's security handler permits.
///
/// The screen leads with whether the file is encrypted at all, because that changes what the
/// list below means: on an unencrypted PDF every permission reads "allowed" simply because
/// nothing is enforcing anything, which is very different from the author having granted it.
class PermissionInspectorView extends StatelessWidget {
  final File file;
  const PermissionInspectorView({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return InspectorScaffold(
      file: file,
      title: ToolStrings.name(context, 'permission-inspector'),
      stateKey: HttpStates.inspectPermissions,
      buildEvent: (cancelToken, upload) => InspectPdfEvent(
        inspect: InspectPdf(file: upload),
        url: PdfService.inspectPermissions,
        stateKey: HttpStates.inspectPermissions,
        cancelToken: cancelToken,
      ),
      report: _build,
    );
  }

  Widget _build(BuildContext context, ThemeData theme, dynamic raw) {
    final l = L10n.of(context);
    final r = asReport(raw);
    if (r == null) return Center(child: Text(L10n.of(context).noAnalysisAvailable));
    final encrypted = r['encrypted'] == true;
    final allowed = (r['allowed'] as Map?)?.cast<String, dynamic>() ?? const {};
    final enc = (r['encryption'] as Map?)?.cast<String, dynamic>();

    bool can(String key) => allowed[key] == true;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          color: encrypted
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(encrypted ? Icons.lock : Icons.lock_open,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  encrypted ? l.inspPermEncryptedNote : l.inspPermUnencryptedNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ]),
          ),
        ),
        InspectorSection(
          title: l.inspPermTitle,
          icon: Icons.verified_user_outlined,
          children: [
            InspectorFlag(l.inspPermPrint, can('print')),
            InspectorFlag(l.inspPermPrintFaithful, can('printFaithful')),
            InspectorFlag(l.inspPermModify, can('modify')),
            InspectorFlag(l.inspPermModifyAnnotations, can('modifyAnnotations')),
            InspectorFlag(l.inspPermFillForm, can('fillInForm')),
            InspectorFlag(l.inspPermExtract, can('extractContent')),
            InspectorFlag(
                l.inspPermExtractAccessibility, can('extractForAccessibility')),
            InspectorFlag(l.inspPermAssemble, can('assembleDocument')),
          ],
        ),
        InspectorSection(
          title: l.inspDocument,
          icon: Icons.description_outlined,
          children: [
            InspectorFlag(l.inspEncrypted, encrypted, trueIsGood: false),
            InspectorFlag(l.inspPermOwnerAccess, r['ownerAccess'] == true),
          ],
        ),
        if (enc != null)
          InspectorSection(
            title: l.inspEncryption,
            icon: Icons.enhanced_encryption_outlined,
            children: [
              InspectorRow(l.inspFilter, enc['filter']?.toString()),
              InspectorRow(l.inspVersion, enc['version']?.toString()),
              InspectorRow(l.inspRevision, enc['revision']?.toString()),
              InspectorRow(l.inspKeyLength, enc['keyLengthBits']?.toString()),
            ],
          ),
      ],
    );
  }
}
