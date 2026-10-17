import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/theme/app_semantic_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/models/enums/compression_level.dart';
import 'package:pdf_craft/models/request/compress_pdf.dart';
import 'package:pdf_craft/models/request/flatten_pdf.dart';
import 'package:pdf_craft/models/request/grayscale_pdf.dart';
import 'package:pdf_craft/models/request/optimize_pdf.dart';
import 'package:pdf_craft/models/request/remove_blank_pages.dart';
import 'package:pdf_craft/models/request/repair_pdf.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/routes.dart';
import 'package:go_router/go_router.dart';

enum _Tool {
  grayscale('Grayscale', Icons.invert_colors, HttpStates.grayscalePdf, 'grayscale-pdf'),
  compress('Compress (recommended)', Icons.compress, HttpStates.compressPdf, 'compress-pdf'),
  repair('Repair', Icons.build_outlined, HttpStates.repairPdf, 'repair-pdf'),
  flatten('Flatten', Icons.layers_clear_outlined, HttpStates.flattenPdf, 'flatten-pdf'),
  optimize('Optimize', Icons.auto_fix_high, HttpStates.optimizePdf, 'optimize-pdf'),
  removeBlankPages('Remove Blank Pages', Icons.delete_sweep_outlined,
      HttpStates.removeBlankPages, 'remove-blank-pages');

  final String label;
  final IconData icon;
  final String stateKey;

  /// Backend tool id whose price lives in the server cost table. Batch runs this operation
  /// once per file, so the real cost is this price multiplied by the file count — which
  /// the screen previously never showed, letting a ten-file compress spend twenty credits
  /// with no warning at all.
  final String creditToolId;

  const _Tool(this.label, this.icon, this.stateKey, this.creditToolId);

  /// Registry id, so the label can reuse the already-translated tool name.
  String get _registryId => switch (this) {
        _Tool.grayscale => 'grayscale',
        _Tool.compress => 'compress',
        _Tool.repair => 'repair',
        _Tool.flatten => 'flatten',
        _Tool.optimize => 'optimize',
        _Tool.removeBlankPages => 'remove-blanks',
      };

  /// `label` stays English for logs; the UI shows this.
  String localizedLabel(BuildContext context) => this == _Tool.compress
      ? L10n.of(context).compressRecommended
      : ToolStrings.name(context, _registryId);
}

enum _FileStatus { pending, processing, done, error }

class _FileItem {
  final File file;
  _FileStatus status;
  String? errorMsg;

  _FileItem(this.file) : status = _FileStatus.pending;
}

class BatchProcessView extends StatefulWidget {
  final List<File> files;
  const BatchProcessView({super.key, required this.files});

  @override
  State<BatchProcessView> createState() => _BatchProcessViewState();
}

class _BatchProcessViewState extends State<BatchProcessView> {
  late final PdfBloc _bloc;
  late final List<_FileItem> _items;
  // Pre-cached file sizes so itemBuilder never calls lengthSync()
  /// Raw byte length per file path. Kept as bytes rather than a formatted string because
  /// the price depends on size, so _totalCost needs the number, not its label.
  final Map<String, int> _fileSizes = {};
  _Tool _tool = _Tool.grayscale;
  int _currentIndex = -1; // -1 = not started
  bool _running = false;

  /// Cancels the item currently uploading.
  ///
  /// A 50-file run had no stop at all: every item was dispatched without a token, so once
  /// started the only way out was to leave the screen — which left the upload running.
  CancelToken? _cancelToken;

  /// Set by [_cancelBatch] so the chain stops instead of advancing to the next file.
  bool _cancelled = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _bloc = BlocProvider.of<PdfBloc>(context);
    _items = widget.files.map((f) => _FileItem(f)).toList();
    _preloadFileSizes();
  }

  @override
  void dispose() {
    // Leaving mid-run used to leave the current upload streaming with nothing to receive it.
    _cancelled = true;
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('screen-disposed');
    }
    super.dispose();
  }

  Future<void> _preloadFileSizes() async {
    for (final f in widget.files) {
      try {
        final len = await f.length();
        if (mounted) setState(() => _fileSizes[f.path] = len);
      } catch (_) {}
    }
  }

  /// Total credits this run will spend.
  ///
  /// Priced per file at the size the server will actually charge for, not the base price times
  /// the file count: the server adds a per-block surcharge, so a batch of large files was being
  /// confirmed at a fraction of what it then took. Files whose length has not been read yet fall
  /// back to the base price, which is what _preloadFileSizes is racing to improve on.
  int get _totalCost {
    final toolId = _tool.creditToolId;
    var total = 0;
    for (final item in _items) {
      final bytes = _fileSizes[item.file.path];
      total += bytes == null
          ? CreditService().costFor(toolId)
          : CreditService().costForSize(toolId, bytes);
    }
    return total;
  }

  Future<void> _startBatch() async {
    // A batch is the one place where a single tap can spend a large number of credits, so
    // it is confirmed as a whole rather than per file.
    if (!await _confirmSpend()) return;
    // The confirmation is a dialog the user can dismiss by leaving the screen entirely.
    if (!mounted) return;

    setState(() {
      _running = true;
      _cancelled = false;
      _finished = false;
      for (final item in _items) {
        item.status = _FileStatus.pending;
      }
      _currentIndex = 0;
    });
    await _processNext();
  }

  /// Shows the run's total price and asks once. Returns false if the user declines or
  /// cannot afford it (in which case they are offered the Credits screen).
  Future<bool> _confirmSpend() async {
    final total = _totalCost;
    if (total <= 0) return true;

    final balance = CreditService().balance;
    final enough = balance >= total;
    final perFile = CreditService().costFor(_tool.creditToolId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).batchDialogTitle(_tool.localizedLabel(ctx), _items.length)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.toll, size: 20),
                const SizedBox(width: 8),
                Text(L10n.of(context).gateUsesCredits(total),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            // Only shown when the total really is the base price times the file count. Once a
            // size surcharge applies the two no longer agree, and a per-file figure that
            // contradicts the total it sits under is worse than no per-file figure.
            if (perFile * _items.length == total) ...[
              const SizedBox(height: 6),
              Text(L10n.of(context).perFilePerCount(perFile, _items.length),
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(L10n.of(context).gateBalance(balance)),
            if (!enough) ...[
              const SizedBox(height: 8),
              Text(L10n.of(context).batchNotEnough,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L10n.of(context).cancel),
          ),
          if (!enough)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
                GoRouter.of(context).pushNamed(AppRoutes.creditsRoute.name);
              },
              child: Text(L10n.of(context).gateGetCredits),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(L10n.of(context).gateUse(total)),
            ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _processNext() async {
    if (_currentIndex >= _items.length) {
      setState(() { _running = false; _finished = true; });
      final done = _items.where((i) => i.status == _FileStatus.done).length;
      final err = _items.where((i) => i.status == _FileStatus.error).length;
      NotificationService.showSnackbar(
        text: L10n.current.batchComplete(done, err),
        kind: done == _items.length ? SnackKind.success : SnackKind.warning,
      );
      return;
    }

    final item = _items[_currentIndex];
    // _processNext is re-entered from the catch below and from the bloc listener, both after
    // an await, so the guard belongs here too rather than only at the call sites.
    if (!mounted || _cancelled) return;
    _cancelToken = CancelToken();
    setState(() => item.status = _FileStatus.processing);

    final baseName = Utility.fileName(file: item.file);
    final outName = '${baseName}_${_tool.name}';

    try {
      final multipart = await MultipartFile.fromFile(item.file.path);
      switch (_tool) {
        case _Tool.grayscale:
          _bloc.add(GrayscalePdfEvent(
            grayscalePdf: GrayscalePdf(outFileName: outName, file: multipart),
            cancelToken: _cancelToken,
          ));
        case _Tool.compress:
          _bloc.add(CompressPdfEvent(
            compressPdf: CompressPdf(
              outFileName: outName,
              level: CompressionLevel.RECOMMENDED,
              file: multipart,
            ),
            cancelToken: _cancelToken,
          ));
        case _Tool.repair:
          _bloc.add(RepairPdfEvent(
            repairPdf: RepairPdf(outFileName: outName, file: multipart),
            cancelToken: _cancelToken,
          ));
        case _Tool.flatten:
          _bloc.add(FlattenPdfEvent(
            flattenPdf: FlattenPdf(outFileName: outName, file: multipart),
            cancelToken: _cancelToken,
          ));
        case _Tool.optimize:
          _bloc.add(OptimizePdfEvent(
            optimizePdf: OptimizePdf(outFileName: outName, file: multipart),
            cancelToken: _cancelToken,
          ));
        case _Tool.removeBlankPages:
          _bloc.add(RemoveBlankPagesEvent(
            removeBlankPages: RemoveBlankPages(file: multipart),
            cancelToken: _cancelToken,
          ));
      }
    } catch (e) {
      // Reached after an await, so the screen may be gone — leaving a batch mid-run used to
      // call setState on a defunct element and then recurse into more of them.
      if (!mounted) return;
      setState(() {
        item.status = _FileStatus.error;
        item.errorMsg = L10n.current.failedToPrepareFile;
        _currentIndex++;
      });
      await _processNext();
    }
  }

  /// Stops the run after the item currently in flight.
  ///
  /// Items already finished keep their results — they are written to disk and paid for — so
  /// this abandons the remainder rather than undoing anything.
  void _cancelBatch() {
    _cancelled = true;
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('cancelled-by-user');
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _finished = true;
      // The in-flight row is marked here, not by the bloc listener: PdfBloc maps a cancelled
      // request back to *idle*, and listenWhen only fires on done or error — so nothing would
      // ever clear this row and it kept its spinner until the next run.
      if (_currentIndex >= 0 && _currentIndex < _items.length) {
        final item = _items[_currentIndex];
        if (item.status == _FileStatus.processing) {
          item.status = _FileStatus.error;
          item.errorMsg = L10n.current.cancelled;
        }
      }
    });
  }

  // Called by BlocListener when the current tool's state changes to done/error.
  void _onBlocResult(bool success, String? error) {
    if (_currentIndex < 0 || _currentIndex >= _items.length) return;
    setState(() {
      _items[_currentIndex].status = success ? _FileStatus.done : _FileStatus.error;
      _items[_currentIndex].errorMsg = error;
      _currentIndex++;
    });
    _processNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return BlocListener<PdfBloc, PdfState>(
      listenWhen: (prev, curr) {
        if (_currentIndex < 0) return false;
        final prevState = prev.httpStates[_tool.stateKey];
        final currState = curr.httpStates[_tool.stateKey];
        return prevState != currState &&
            (currState?.done == true || currState?.error != null);
      },
      listener: (context, state) {
        final s = state.httpStates[_tool.stateKey];
        _onBlocResult(s?.done == true, s?.error);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(L10n.of(context)
              .batchAppBarTitle(ToolStrings.name(context, 'batch'), _items.length)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.of(context).toolLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<_Tool>(
                    initialValue: _tool,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _Tool.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Icon(t.icon, size: 18, color: primary),
                                  const SizedBox(width: 8),
                                  // "Remove Blank Pages" overruns the closed dropdown on a
                                  // narrow screen.
                                  Flexible(
                                    child: Text(t.localizedLabel(context), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: _running ? null : (v) { if (v != null) setState(() => _tool = v); },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  return ListTile(
                    dense: true,
                    leading: _statusIcon(context, item.status, primary),
                    title: Text(
                      item.file.path.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: item.errorMsg != null
                        ? Text(item.errorMsg!,
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 11))
                        : Text(
                            _fileSizes[item.file.path] == null
                                ? ''
                                : Utility.bytesToSize(_fileSizes[item.file.path]!),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 16, 16,
                  16 + MediaQuery.viewPaddingOf(context).bottom),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: _finished
                  ? OutlinedButton(
                      onPressed: _startBatch,
                      child: Text(L10n.of(context).runAgain),
                    )
                  : _running
                      // A Cancel while running, rather than a disabled button: the only way to
                      // stop a 50-file run used to be leaving the screen, which left the
                      // current upload going.
                      ? OutlinedButton.icon(
                          onPressed: _cancelBatch,
                          icon: const Icon(Icons.close),
                          label: Text(L10n.of(context).cancel),
                        )
                      : FilledButton(
                          onPressed: _startBatch,
                          child: Text(L10n.of(context).startBatch),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Row status, in scheme roles.
  ///
  /// `grey.shade400` on the white card measured 1.88:1, so a row waiting to be processed looked
  /// like a row with no status at all — and the done/error glyphs used raw palette colours that
  /// do not respond to the theme.
  Widget _statusIcon(BuildContext context, _FileStatus status, Color primary) {
    final theme = Theme.of(context);
    switch (status) {
      case _FileStatus.pending:
        return Icon(Icons.schedule_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant);
      case _FileStatus.processing:
        return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primary));
      case _FileStatus.done:
        return Icon(Icons.check_circle_outline,
            size: 20, color: AppSemanticColors.of(context).success);
      case _FileStatus.error:
        return Icon(Icons.error_outline, size: 20, color: theme.colorScheme.error);
    }
  }
}
