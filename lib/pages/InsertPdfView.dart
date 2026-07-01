import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/insert-pdf.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdfx/pdfx.dart';

/// Insert PDF into PDF: places one PDF inside another after a chosen page.
/// Receives two files; either can be the base (swap), then pick the position.
class InsertPdfView extends StatefulWidget {
  final List<File> files;
  const InsertPdfView({super.key, required this.files});

  @override
  State<InsertPdfView> createState() => _InsertPdfViewState();
}

class _InsertPdfViewState extends State<InsertPdfView>
    with ToolResultHandler, ToolViewMixin {
  late File _base = widget.files[0];
  late File _insert = widget.files[1];
  int _basePages = 0;
  // 0 = at start; k = after page k of the base.
  int _position = 0;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.INSERT_PDF]);
    _loadBaseCount();
  }

  Future<void> _loadBaseCount() async {
    try {
      final doc = await PdfDocument.openFile(_base.path);
      if (mounted) setState(() { _basePages = doc.pagesCount; if (_position > _basePages) _position = _basePages; });
      await doc.close();
    } catch (_) {
      if (mounted) setState(() => _basePages = 0);
    }
  }

  void _swap() {
    setState(() {
      final t = _base;
      _base = _insert;
      _insert = t;
      _position = 0;
      _basePages = 0;
    });
    _loadBaseCount();
  }

  String _name(File f) => f.path.split('/').last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Insert PDF into PDF')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.INSERT_PDF] != c.httpStates[HttpStates.INSERT_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.INSERT_PDF] != c.httpStates[HttpStates.INSERT_PDF],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.INSERT_PDF], successMessage: 'PDF inserted'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.INSERT_PDF]?.loading == true;
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
                        tooltip: 'Swap base / insert',
                        onPressed: _swap,
                      ),
                    ),
                    _fileCard(theme, 'Insert this', _insert, Icons.note_add_outlined),
                    const SizedBox(height: 20),
                    Text('Insert position', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      _position == 0
                          ? 'At the very beginning'
                          : 'After page $_position of the base document',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    if (_basePages > 0)
                      Slider(
                        value: _position.toDouble(),
                        min: 0,
                        max: _basePages.toDouble(),
                        divisions: _basePages,
                        label: _position == 0 ? 'Start' : 'After $_position',
                        onChanged: (v) => setState(() => _position = v.round()),
                      )
                    else
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
                  onPressed: (loading || _basePages == 0) ? null : _onInsert,
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Insert & Save'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.INSERT_PDF], label: 'Inserting PDF'),
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

  Future<void> _onInsert() async {
    final base = await MultipartFile.fromFile(_base.path);
    final insert = await MultipartFile.fromFile(_insert.path);
    if (!mounted) return;
    runTool((cancelToken) => InsertPdfEvent(
          insertPdf: InsertPdf(
            outFileName: 'inserted',
            afterPage: _position - 1, // 0 => -1 (start); k => after page k-1
            file: base,
            insert: insert,
          ),
          cancelToken: cancelToken,
        ));
  }
}
