import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/remove-metadata.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

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
    resetToolState([HttpStates.REMOVE_METADATA]);
  }

  static const _stripped = [
    ('Title', Icons.title),
    ('Author', Icons.person_outline),
    ('Subject & Keywords', Icons.label_outline),
    ('Creator & Producer app', Icons.build_outlined),
    ('Creation & modified dates', Icons.schedule_outlined),
    ('XMP metadata', Icons.data_object),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Remove Metadata')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.REMOVE_METADATA] != c.httpStates[HttpStates.REMOVE_METADATA],
        listenWhen: (p, c) => p.httpStates[HttpStates.REMOVE_METADATA] != c.httpStates[HttpStates.REMOVE_METADATA],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.REMOVE_METADATA], successMessage: 'Metadata removed'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.REMOVE_METADATA]?.loading == true;
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
                          'Strip identifying information from this PDF before you share it.',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text('The following will be removed:',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < _stripped.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 52),
                            ListTile(
                              dense: true,
                              leading: Icon(_stripped[i].$2, size: 20, color: theme.colorScheme.primary),
                              title: Text(_stripped[i].$1),
                              trailing: const Icon(Icons.close, size: 16, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The page content is not changed. Note: text visible on the page itself is not metadata — use Redact for that.',
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
                  label: const Text('Remove Metadata'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.REMOVE_METADATA], label: 'Removing metadata'),
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
