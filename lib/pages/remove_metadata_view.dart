import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/remove_metadata.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// Remove Metadata: strips identifying document info (title, author, creator,
/// producer, dates) and any XMP metadata so the exported PDF carries no traces.
class RemoveMetadataView extends StatefulWidget {
  final File file;
  const RemoveMetadataView({super.key, required this.file});

  @override
  State<RemoveMetadataView> createState() => _RemoveMetadataViewState();
}

class _RemoveMetadataViewState extends State<RemoveMetadataView>
    with ToolResultHandler, ToolViewMixin {
  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.removeMetadata]);
  }

  /// Localized at build time, so the list follows the app language.
  List<(String, IconData)> _strippedItems(BuildContext context) => [
    (L10n.of(context).metaTitle, Icons.title),
    (L10n.of(context).metaAuthor, Icons.person_outline),
    (L10n.of(context).metaSubjectKeywords, Icons.label_outline),
    (L10n.of(context).metaCreatorProducer, Icons.build_outlined),
    (L10n.of(context).metaDates, Icons.schedule_outlined),
    (L10n.of(context).metaXmp, Icons.data_object),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stripped = _strippedItems(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'remove-metadata'))),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.removeMetadata] != c.httpStates[HttpStates.removeMetadata],
        listenWhen: (p, c) => p.httpStates[HttpStates.removeMetadata] != c.httpStates[HttpStates.removeMetadata],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.removeMetadata], successMessage: L10n.of(context).metadataRemoved),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.removeMetadata]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          L10n.of(context).removeMetadataIntro,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text(L10n.of(context).followingWillBeRemoved,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < stripped.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 52),
                            ListTile(
                              dense: true,
                              leading: Icon(stripped[i].$2, size: 20, color: theme.colorScheme.primary),
                              title: Text(stripped[i].$1),
                              trailing: const Icon(Icons.close, size: 16, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      L10n.of(context).removeMetadataNote,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55), height: 1.4),
                    ),
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
                  onPressed: loading ? null : _onRemove,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(ToolStrings.name(context, 'remove-metadata')),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.removeMetadata], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  Future<void> _onRemove() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => RemoveMetadataEvent(
          removeMetadata: RemoveMetadata(file: file),
          cancelToken: cancelToken,
        ));
  }
}
