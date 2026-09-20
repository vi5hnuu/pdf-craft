import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/request/inspect_pdf.dart';
import 'package:pdf_craft/pages/inspector/inspector_scaffold.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/widgets/banner_add.dart';

/// Lists the file's indirect (COS) objects.
///
/// This one does not use [InspectorScaffold]: a real document runs to thousands of objects, so
/// the listing is paged and the screen has to accumulate pages rather than replace the report on
/// each response. Everything else — the row widgets, the section card — is shared.
class ObjectExplorerView extends StatefulWidget {
  final File file;
  const ObjectExplorerView({super.key, required this.file});

  @override
  State<ObjectExplorerView> createState() => _ObjectExplorerViewState();
}

class _ObjectExplorerViewState extends State<ObjectExplorerView>
    with ToolResultHandler, ToolViewMixin {
  static const _pageSize = 100;

  final List<Map<String, dynamic>> _objects = [];
  int _total = 0;
  MultipartFile? _upload;

  /// The offset already requested. Distinct from `_objects.length` so a request in flight is not
  /// issued twice by a fast scroll.
  int _requested = 0;

  @override
  void initState() {
    super.initState();
    resetToolState([HttpStates.exploreObjects]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    // A MultipartFile is a one-shot stream, so each page needs a fresh one built from the file.
    _upload = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    final offset = _requested;
    runTool((cancelToken) => InspectPdfEvent(
          inspect: InspectPdf(
              file: _upload!, query: {'offset': offset, 'limit': _pageSize}),
          url: PdfService.exploreObjects,
          stateKey: HttpStates.exploreObjects,
          cancelToken: cancelToken,
        ));
  }

  void _absorb(dynamic raw) {
    if (raw is! Map) return;
    final r = raw.cast<String, dynamic>();
    final rows = (r['objects'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    setState(() {
      _total = (r['total'] as num?)?.toInt() ?? _total;
      _objects.addAll(rows);
      _requested = _objects.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'object-explorer'))),
      body: Column(children: [
        Expanded(
          child: BlocConsumer<PdfBloc, PdfState>(
            buildWhen: (p, c) =>
                p.httpStates[HttpStates.exploreObjects] !=
                c.httpStates[HttpStates.exploreObjects],
            listenWhen: (p, c) =>
                p.httpStates[HttpStates.exploreObjects] !=
                c.httpStates[HttpStates.exploreObjects],
            listener: (context, state) {
              final s = state.httpStates[HttpStates.exploreObjects];
              if (s?.done == true) _absorb(s?.extras?['report']);
              if (s?.error != null) {
                NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
              }
            },
            builder: (context, state) {
              final s = state.httpStates[HttpStates.exploreObjects];
              final loading = s == null || s.loading == true;
              if (_objects.isEmpty && loading) {
                return Center(
                    child: SpinKitThreeBounce(color: theme.colorScheme.primary, size: 36));
              }
              if (_objects.isEmpty && s?.error != null) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(s!.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _fetch, child: Text(l.retry)),
                  ]),
                );
              }
              final hasMore = _objects.length < _total;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                itemCount: _objects.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(l.inspObjectsTotal(_total),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    );
                  }
                  if (i == _objects.length + 1) {
                    if (!hasMore) return const SizedBox(height: 8);
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: loading
                            ? const CircularProgressIndicator()
                            : OutlinedButton.icon(
                                onPressed: _fetch,
                                icon: const Icon(Icons.expand_more),
                                label: Text(l.inspLoadMore)),
                      ),
                    );
                  }
                  final o = _objects[i - 1];
                  return _row(theme, l, o);
                },
              );
            },
          ),
        ),
        const BannerAdd(),
      ]),
    );
  }

  Widget _row(ThemeData theme, AppLocalizations l, Map<String, dynamic> o) {
    final subtype = o['subtype']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: SeverityChip('info', '${o['type']}'),
        title: Text(l.inspObjectN(o['number'] ?? '?', o['generation'] ?? 0),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [if (subtype != null && subtype.isNotEmpty) '/$subtype', '${o['summary'] ?? ''}']
              .where((s) => s.isNotEmpty)
              .join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
