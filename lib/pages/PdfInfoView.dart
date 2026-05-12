import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf_craft/models/request/get-metadata.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

class PdfInfoView extends StatefulWidget {
  final File file;
  const PdfInfoView({super.key, required this.file});

  @override
  State<PdfInfoView> createState() => _PdfInfoViewState();
}

class _PdfInfoViewState extends State<PdfInfoView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);

  @override
  void initState() {
    super.initState();
    // Auto-fetch metadata on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  void _fetch() async {
    _bloc.add(GetMetadataEvent(
      getMetadata: GetMetadata(file: await MultipartFile.fromFile(widget.file.path)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Info'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.GET_METADATA] != c.httpStates[HttpStates.GET_METADATA],
        listenWhen: (p, c) => p.httpStates[HttpStates.GET_METADATA] != c.httpStates[HttpStates.GET_METADATA],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.GET_METADATA];
          if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          final s = state.httpStates[HttpStates.GET_METADATA];
          if (s?.loading == true) {
            return Center(child: SpinKitThreeBounce(color: theme.colorScheme.primary, size: 36));
          }
          if (s?.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(s!.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _fetch, child: const Text('Retry')),
                ],
              ),
            );
          }
          final meta = s?.extras?['metadata'] as Map<String, dynamic>?;
          if (meta == null) {
            return const SizedBox.shrink();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // File name header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
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
      ),
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
