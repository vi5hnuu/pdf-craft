import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/get_form_fields.dart';
import 'package:pdf_craft/pages/inspector/inspector_scaffold.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// A read-only view of an existing PDF's AcroForm fields.
///
/// Reuses the existing `/get-form-fields` call rather than adding an endpoint — the data was
/// already available, it just had no screen of its own. Until now it was only ever fetched by
/// the flatten tool, which used it to build inputs and never showed the field definitions.
class FormInspectorView extends StatelessWidget {
  final File file;
  const FormInspectorView({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return InspectorScaffold(
      file: file,
      title: ToolStrings.name(context, 'form-inspector'),
      stateKey: HttpStates.getFormFields,
      // get-form-fields predates the generic inspector path and stores under its own key.
      extrasKey: 'fields',
      buildEvent: (cancelToken, upload) => GetFormFieldsEvent(
        getFormFields: GetFormFields(file: upload),
        cancelToken: cancelToken,
      ),
      report: _build,
    );
  }

  Widget _build(BuildContext context, ThemeData theme, dynamic raw) {
    final l = L10n.of(context);
    final fields = (raw is List)
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];

    if (fields.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.ballot_outlined,
              size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(l.inspFormNoFields),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(l.inspFormFieldCount(fields.length),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        for (final f in fields)
          InspectorSection(
            title: '${f['name'] ?? '—'}',
            icon: Icons.input,
            children: [
              InspectorRow(l.inspFieldType, f['type']?.toString()),
              InspectorRow(l.inspFieldValue, f['value']?.toString()),
              if (f['page'] != null) InspectorRow(l.inspFieldPage, '${f['page']}'),
              if (f['options'] is List && (f['options'] as List).isNotEmpty)
                InspectorRow(l.inspFieldOptions, (f['options'] as List).join(', ')),
              if (f['required'] == true) InspectorFlag(l.inspFieldRequired, true),
              if (f['readOnly'] == true) InspectorFlag(l.inspFieldReadOnly, true),
            ],
          ),
      ],
    );
  }
}
