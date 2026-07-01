import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf_craft/models/request/analyze-pdf.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';

/// Analyze PDF: a read-only report bundling page/word counts and detected
/// blank / duplicate / landscape pages plus embedded-resource counts.
class AnalyzePdfView extends StatefulWidget {
  final File file;
  const AnalyzePdfView({super.key, required this.file});

  @override
  State<AnalyzePdfView> createState() => _AnalyzePdfViewState();
}

class _AnalyzePdfViewState extends State<AnalyzePdfView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    _bloc.add(AnalyzePdfEvent(analyzePdf: AnalyzePdf(file: await MultipartFile.fromFile(widget.file.path))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Analyze PDF')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.ANALYZE_PDF] != c.httpStates[HttpStates.ANALYZE_PDF],
        listenWhen: (p, c) => p.httpStates[HttpStates.ANALYZE_PDF] != c.httpStates[HttpStates.ANALYZE_PDF],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.ANALYZE_PDF];
          if (s?.error != null) NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
        },
        builder: (context, state) {
          final s = state.httpStates[HttpStates.ANALYZE_PDF];
          if (s?.loading == true || s == null) {
            return Center(child: SpinKitThreeBounce(color: theme.colorScheme.primary, size: 36));
          }
          if (s.error != null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 12),
                Text(s.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _fetch, child: const Text('Retry')),
              ]),
            );
          }
          final a = (s.extras?['analysis'] as Map?)?.cast<String, dynamic>();
          if (a == null) return const Center(child: Text('No analysis available'));
          return _buildReport(theme, a);
        },
      ),
    );
  }

  Widget _buildReport(ThemeData theme, Map<String, dynamic> a) {
    final blank = (a['blankPages'] as List?)?.cast<int>() ?? const [];
    final landscape = (a['landscapePages'] as List?)?.cast<int>() ?? const [];
    final dupGroups = (a['duplicatePageGroups'] as List?) ?? const [];
    final size = (a['fileSizeBytes'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statGrid(theme, [
          _Stat('Pages', '${a['pageCount'] ?? '—'}', Icons.description_outlined),
          _Stat('Words', '${a['wordCount'] ?? '—'}', Icons.text_fields),
          _Stat('Characters', '${a['characterCount'] ?? '—'}', Icons.abc),
          _Stat('Size', Utility.bytesToSize(size), Icons.data_usage),
          _Stat('Images', '${a['imageCount'] ?? 0}', Icons.image_outlined),
          _Stat('Fonts', '${a['fontCount'] ?? 0}', Icons.font_download_outlined),
          _Stat('Attachments', '${a['attachmentCount'] ?? 0}', Icons.attachment_outlined),
          _Stat('Encrypted', (a['encrypted'] == true) ? 'Yes' : 'No', Icons.lock_outline),
        ]),
        const SizedBox(height: 16),
        _listCard(theme, 'Blank pages', blank.isEmpty ? 'None' : blank.join(', '), Icons.crop_din),
        _listCard(theme, 'Landscape pages', landscape.isEmpty ? 'None' : landscape.join(', '), Icons.crop_landscape),
        _listCard(
          theme,
          'Duplicate page groups',
          dupGroups.isEmpty
              ? 'None'
              : dupGroups.map((g) => '[${(g as List).join(', ')}]').join('  '),
          Icons.content_copy,
        ),
      ],
    );
  }

  Widget _statGrid(ThemeData theme, List<_Stat> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: stats
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(children: [
                  Icon(s.icon, size: 22, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(s.label,
                            style: TextStyle(
                                fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ]),
              ))
          .toList(),
    );
  }

  Widget _listCard(ThemeData theme, String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.75))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  _Stat(this.label, this.value, this.icon);
}
