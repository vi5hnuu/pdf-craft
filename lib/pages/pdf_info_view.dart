import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/widgets/tool_error_state.dart';
import 'package:pdf_craft/theme/app_spacing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/get_metadata.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/widgets/tool_pane.dart';

class PdfInfoView extends StatefulWidget {
  final File file;
  const PdfInfoView({super.key, required this.file});

  @override
  State<PdfInfoView> createState() => _PdfInfoViewState();
}

class _PdfInfoViewState extends State<PdfInfoView>
    with ToolResultHandler, ToolViewMixin {

  @override
  void initState() {
    super.initState();
    // Auto-fetch metadata on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    resetToolState([HttpStates.getMetadata]);
  }

  void _fetch() async {
    final uploadFile = await readForUpload(widget.file);
    if (uploadFile == null) return;
    if (!mounted) return;
    runTool((cancelToken) => GetMetadataEvent(
      getMetadata: GetMetadata(file: uploadFile), cancelToken: cancelToken));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'pdf-info'))),
      body: ToolPane(child: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.getMetadata] != c.httpStates[HttpStates.getMetadata],
        listenWhen: (p, c) => p.httpStates[HttpStates.getMetadata] != c.httpStates[HttpStates.getMetadata],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.getMetadata];
          if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, kind: SnackKind.error);
          }
        },
        builder: (context, state) {
          final s = state.httpStates[HttpStates.getMetadata];
          if (s?.loading == true) {
            return Center(child: SpinKitThreeBounce(color: theme.colorScheme.primary, size: 36));
          }
          if (s?.error != null) {
            return ToolErrorState(message: s!.error, onRetry: _fetch);
          }
          final meta = s?.extras?['metadata'] as Map<String, dynamic>?;
          if (meta == null) {
            return const SizedBox.shrink();
          }
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // File name header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.surface)),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.file.path.split('/').last,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Metadata fields
              ...meta.entries.map((e) => _MetaTile(label: _formatKey(e.key), value: e.value?.toString() ?? '—')),
            ],
          );
        },
      )),
    );
  }

  String _formatKey(String key) {
    // Convert snake_case / camelCase to "Title Case"
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _MetaTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetaTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
