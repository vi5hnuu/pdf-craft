import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/replace-pages.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdfx/pdfx.dart';

/// Replace Pages: swaps a page range in the base document for all pages of a
/// second PDF. Receives two files; either can be the base (swap).
class ReplacePagesView extends StatefulWidget {
  final List<File> files;
  const ReplacePagesView({super.key, required this.files});

  @override
  State<ReplacePagesView> createState() => _ReplacePagesViewState();
}

class _ReplacePagesViewState extends State<ReplacePagesView>
    with ToolResultHandler, ToolViewMixin {
  late File _base = widget.files[0];
  late File _replacement = widget.files[1];
  int _basePages = 0;
  int _from = 1;
  int _to = 1;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.REPLACE_PAGES]);
    _loadBaseCount();
  }

  Future<void> _loadBaseCount() async {
    try {
      final doc = await PdfDocument.openFile(_base.path);
      if (mounted) {
        setState(() {
          _basePages = doc.pagesCount;
          _from = 1;
          _to = _basePages == 0 ? 1 : 1;
        });
      }
      await doc.close();
    } catch (_) {
      if (mounted) setState(() => _basePages = 0);
    }
  }

  void _swap() {
    setState(() {
      final t = _base;
      _base = _replacement;
      _replacement = t;
      _basePages = 0;
    });
    _loadBaseCount();
  }

  String _name(File f) => f.path.split('/').last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Replace Pages')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.REPLACE_PAGES] != c.httpStates[HttpStates.REPLACE_PAGES],
        listenWhen: (p, c) => p.httpStates[HttpStates.REPLACE_PAGES] != c.httpStates[HttpStates.REPLACE_PAGES],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.REPLACE_PAGES], successMessage: 'Pages replaced'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.REPLACE_PAGES]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _fileCard(theme, 'Base document', _base, Icons.picture_as_pdf),
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.swap_vert),
                        tooltip: 'Swap base / replacement',
                        onPressed: _swap,
                      ),
                    ),
                    _fileCard(theme, 'Replace with', _replacement, Icons.find_replace),
                    const SizedBox(height: 20),
                    Text('Range to replace', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (_basePages > 0) ...[
                      Text('Base has $_basePages page${_basePages == 1 ? '' : 's'}. Replacing pages $_from–$_to.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: RangeValues(_from.toDouble(), _to.toDouble()),
                        min: 1,
                        max: _basePages.toDouble(),
                        divisions: _basePages > 1 ? _basePages - 1 : null,
                        labels: RangeLabels('$_from', '$_to'),
                        onChanged: (v) => setState(() {
                          _from = v.start.round();
                          _to = v.end.round();
                        }),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Reading base document…'),
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
                  onPressed: (loading || _basePages == 0) ? null : _onReplace,
                  icon: const Icon(Icons.find_replace),
                  label: const Text('Replace & Save'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.REPLACE_PAGES], label: 'Replacing pages'),
          ]);
        },
      ),
    );
  }

  Widget _fileCard(ThemeData theme, String role, File f, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(_name(f), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(role),
      ),
    );
  }

  Future<void> _onReplace() async {
    final base = await MultipartFile.fromFile(_base.path);
    final repl = await MultipartFile.fromFile(_replacement.path);
    if (!mounted) return;
    runTool((cancelToken) => ReplacePagesEvent(
          replacePages: ReplacePages(
            outFileName: 'replaced_pages',
            from: _from,
            to: _to,
            file: base,
            replacement: repl,
          ),
          cancelToken: cancelToken,
        ));
  }
}
