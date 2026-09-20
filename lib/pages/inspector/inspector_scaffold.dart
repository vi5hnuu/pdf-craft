/// Shared chrome for the read-only inspectors.
///
/// Six tools — permissions, security, form, structure, objects and the JSON export — all do the
/// same thing: upload the PDF, get a JSON report, render it. Only the rendering differs, so the
/// fetch, the loading and error states, the retry, and the share/copy actions live here once.
///
/// These tools produce no file, so none of them goes through [ToolViewMixin.handleToolState],
/// which exists to navigate to a saved PDF.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/file_store.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:share_plus/share_plus.dart';

class InspectorScaffold extends StatefulWidget {
  final File file;
  final String title;

  /// The [HttpStates] key this tool's result lands under.
  final String stateKey;

  /// Which entry of the finished state's `extras` holds the payload — `report` for the generic
  /// inspectors, `fields` for the form inspector, which reuses the existing get-form-fields call.
  final String extrasKey;

  /// Builds the event that fetches the report.
  final PdfEvent Function(CancelToken cancelToken, MultipartFile upload) buildEvent;

  /// Renders the payload. Called only with a non-null report.
  final Widget Function(BuildContext context, ThemeData theme, dynamic report) report;

  const InspectorScaffold({
    super.key,
    required this.file,
    required this.title,
    required this.stateKey,
    required this.buildEvent,
    required this.report,
    this.extrasKey = 'report',
  });

  @override
  State<InspectorScaffold> createState() => _InspectorScaffoldState();
}

class _InspectorScaffoldState extends State<InspectorScaffold>
    with ToolResultHandler, ToolViewMixin {
  dynamic _report;

  @override
  void initState() {
    super.initState();
    resetToolState([widget.stateKey]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final upload = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => widget.buildEvent(cancelToken, upload));
  }

  String get _json => const JsonEncoder.withIndent('  ').convert(_report);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _json));
    if (mounted) {
      NotificationService.showSnackbar(
          text: L10n.current.copiedToClipboard, color: Colors.green);
    }
  }

  /// Writes the report next to the app's other output and hands it to the share sheet, so a
  /// report can leave the phone as a file rather than as a wall of copied text.
  Future<void> _share() async {
    try {
      final dir = Directory(Constants.processedDirPath);
      if (!dir.existsSync()) await dir.create(recursive: true);
      final base = widget.file.path.split('/').last.replaceAll(RegExp(r'\.pdf$'), '');
      final out = File('${dir.path}/$base-${widget.stateKey.toLowerCase()}.json');
      await out.writeAsString(_json);
      FileStore().changed();
      await Share.shareXFiles([XFile(out.path)]);
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.errToolFailed, color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: _report == null
            ? null
            : [
                IconButton(
                    icon: const Icon(Icons.copy_all_outlined),
                    tooltip: L10n.of(context).copy,
                    onPressed: _copy),
                IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: L10n.of(context).actionShare,
                    onPressed: _share),
              ],
      ),
      body: Column(children: [
        Expanded(
          child: BlocConsumer<PdfBloc, PdfState>(
            buildWhen: (p, c) => p.httpStates[widget.stateKey] != c.httpStates[widget.stateKey],
            listenWhen: (p, c) => p.httpStates[widget.stateKey] != c.httpStates[widget.stateKey],
            listener: (context, state) {
              final s = state.httpStates[widget.stateKey];
              if (s?.done == true) {
                setState(() => _report = s?.extras?[widget.extrasKey]);
              }
              // No snackbar: the body below already gives the error its own icon, the message
              // and a Retry. A snackbar repeated it a second time, over the top of the retry
              // button the user needs.
            },
            builder: (context, state) {
              final s = state.httpStates[widget.stateKey];
              if (s == null || s.loading == true) {
                return Center(
                    child: SpinKitThreeBounce(color: theme.colorScheme.primary, size: 36));
              }
              if (s.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, size: 56, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(s.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _fetch, child: Text(L10n.of(context).retry)),
                    ]),
                  ),
                );
              }
              final report = _report ?? s.extras?[widget.extrasKey];
              if (report == null) {
                return Center(child: Text(L10n.of(context).noAnalysisAvailable));
              }
              return widget.report(context, theme, report);
            },
          ),
        ),
        // A report is a read-only screen with nothing in flight and no document on display —
        // the one place in a tool flow where a banner does not get in the way.
        const BannerAdd(),
      ]),
    );
  }
}

/// The report as a map, or null when the server sent something else.
///
/// The payload is server JSON, which is the one input a report screen does not control. A bare
/// `as Map` inside `build` turns any surprise — an error envelope, a future shape change — into
/// a red screen rather than the "no report" state that is already there for exactly this.
Map<String, dynamic>? asReport(dynamic raw) =>
    raw is Map ? raw.cast<String, dynamic>() : null;

// ── Presentation pieces shared by the six reports ──────────────────────────────

/// A titled group of rows.
class InspectorSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const InspectorSection(
      {super.key, required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ...children,
        ]),
      ),
    );
  }
}

/// One `label: value` line. [value] is rendered as an em dash when null or blank, so an absent
/// field reads as absent rather than as an empty row.
class InspectorRow extends StatelessWidget {
  final String label;
  final String? value;
  const InspectorRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Proportional rather than a fixed 140px: that width was measured against the English
        // labels, and the longer Hindi ones wrapped to three lines inside it while the value
        // beside them kept the same cramped column on a narrow phone.
        Expanded(
          flex: 2,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: SelectableText(
            (value == null || value!.isEmpty) ? '—' : value!,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ]),
    );
  }
}

/// Whether something is **allowed**: green tick for yes, red cross for no.
///
/// Only for permissions and constraints, where yes and no genuinely are good and bad news. A
/// plain fact about the file — "is it encrypted?", "does it have a form?" — goes through
/// [InspectorFact] instead, which passes no judgement.
class InspectorFlag extends StatelessWidget {
  final String label;
  final bool value;
  const InspectorFlag(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final good = value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(value ? Icons.check_circle : Icons.cancel,
            size: 18, color: good ? Colors.green : Colors.red.shade400),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
      ]),
    );
  }
}

/// A statement of fact: yes or no, with no judgement attached.
///
/// Distinct from [InspectorFlag], which says whether something is *allowed* — there, a tick is
/// good news and a cross is bad. A fact is neither. Rendering "Encrypted: no" as a green cross,
/// or "Has a form: no" as a red one, invited the reader to see a verdict that was not being
/// made.
class InspectorFact extends StatelessWidget {
  final String label;
  final bool value;
  const InspectorFact(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(value ? Icons.check : Icons.remove,
            size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value ? L10n.of(context).yes : L10n.of(context).no,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// A coloured severity pill, used by the security scanner.
class SeverityChip extends StatelessWidget {
  final String severity;
  final String label;
  const SeverityChip(this.severity, this.label, {super.key});

  static Color colorFor(String severity) => switch (severity) {
        'high' => Colors.red,
        'medium' => Colors.orange,
        'low' => Colors.amber.shade800,
        'clean' => Colors.green,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final c = colorFor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
