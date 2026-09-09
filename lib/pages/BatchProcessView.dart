import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/enums/compression-level.dart';
import 'package:pdf_craft/models/request/compress-pdf.dart';
import 'package:pdf_craft/models/request/flatten-pdf.dart';
import 'package:pdf_craft/models/request/grayscale-pdf.dart';
import 'package:pdf_craft/models/request/optimize-pdf.dart';
import 'package:pdf_craft/models/request/remove-blank-pages.dart';
import 'package:pdf_craft/models/request/repair-pdf.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/routes.dart';
import 'package:go_router/go_router.dart';

enum _Tool {
  grayscale('Grayscale', Icons.invert_colors, HttpStates.GRAYSCALE_PDF, 'grayscale-pdf'),
  compress('Compress (recommended)', Icons.compress, HttpStates.COMPRESS_PDF, 'compress-pdf'),
  repair('Repair', Icons.build_outlined, HttpStates.REPAIR_PDF, 'repair-pdf'),
  flatten('Flatten', Icons.layers_clear_outlined, HttpStates.FLATTEN_PDF, 'flatten-pdf'),
  optimize('Optimize', Icons.auto_fix_high, HttpStates.OPTIMIZE_PDF, 'optimize-pdf'),
  removeBlankPages('Remove Blank Pages', Icons.delete_sweep_outlined,
      HttpStates.REMOVE_BLANK_PAGES, 'remove-blank-pages');

  final String label;
  final IconData icon;
  final String stateKey;

  /// Backend tool id whose price lives in the server cost table. Batch runs this operation
  /// once per file, so the real cost is this price multiplied by the file count — which
  /// the screen previously never showed, letting a ten-file compress spend twenty credits
  /// with no warning at all.
  final String creditToolId;

  const _Tool(this.label, this.icon, this.stateKey, this.creditToolId);
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
  final Map<String, String> _fileSizes = {};
  _Tool _tool = _Tool.grayscale;
  int _currentIndex = -1; // -1 = not started
  bool _running = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _bloc = BlocProvider.of<PdfBloc>(context);
    _items = widget.files.map((f) => _FileItem(f)).toList();
    _preloadFileSizes();
  }

  Future<void> _preloadFileSizes() async {
    for (final f in widget.files) {
      try {
        final len = await f.length();
        if (mounted) setState(() => _fileSizes[f.path] = Utility.bytesToSize(len));
      } catch (_) {}
    }
  }

  /// Total credits this run will spend: the per-file price times the number of files.
  int get _totalCost => CreditService().costFor(_tool.creditToolId) * _items.length;

  Future<void> _startBatch() async {
    // A batch is the one place where a single tap can spend a large number of credits, so
    // it is confirmed as a whole rather than per file.
    if (!await _confirmSpend()) return;
    // The confirmation is a dialog the user can dismiss by leaving the screen entirely.
    if (!mounted) return;

    setState(() {
      _running = true;
      _finished = false;
      for (final item in _items) item.status = _FileStatus.pending;
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
        title: Text('${_tool.label} — ${_items.length} files'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.toll, size: 20),
                const SizedBox(width: 8),
                Text('Uses $total credit${total > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text('$perFile per file × ${_items.length} files',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('Your balance: $balance'),
            if (!enough) ...[
              const SizedBox(height: 8),
              Text('Not enough credits for this batch.',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          if (!enough)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
                GoRouter.of(context).pushNamed(AppRoutes.creditsRoute.name);
              },
              child: const Text('Get credits'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Use $total'),
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
        text: 'Batch complete: $done succeeded, $err failed',
        color: done == _items.length ? Colors.green : Colors.orange,
      );
      return;
    }

    final item = _items[_currentIndex];
    setState(() => item.status = _FileStatus.processing);

    final baseName = Utility.fileName(file: item.file);
    final outName = '${baseName}_${_tool.name}';

    try {
      final multipart = await MultipartFile.fromFile(item.file.path);
      switch (_tool) {
        case _Tool.grayscale:
          _bloc.add(GrayscalePdfEvent(
            grayscalePdf: GrayscalePdf(outFileName: outName, file: multipart),
          ));
        case _Tool.compress:
          _bloc.add(CompressPdfEvent(
            compressPdf: CompressPdf(
              outFileName: outName,
              level: CompressionLevel.RECOMMENDED,
              file: multipart,
            ),
          ));
        case _Tool.repair:
          _bloc.add(RepairPdfEvent(
            repairPdf: RepairPdf(outFileName: outName, file: multipart),
          ));
        case _Tool.flatten:
          _bloc.add(FlattenPdfEvent(
            flattenPdf: FlattenPdf(outFileName: outName, file: multipart),
          ));
        case _Tool.optimize:
          _bloc.add(OptimizePdfEvent(
            optimizePdf: OptimizePdf(outFileName: outName, file: multipart),
          ));
        case _Tool.removeBlankPages:
          _bloc.add(RemoveBlankPagesEvent(
            removeBlankPages: RemoveBlankPages(file: multipart),
          ));
      }
    } catch (e) {
      setState(() {
        item.status = _FileStatus.error;
        item.errorMsg = 'Failed to prepare file';
        _currentIndex++;
      });
      await _processNext();
    }
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
          title: Text('Batch Process (${_items.length} files)'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tool', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<_Tool>(
                    value: _tool,
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
                                    child: Text(t.label, overflow: TextOverflow.ellipsis),
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
                    leading: _statusIcon(item.status, primary),
                    title: Text(
                      item.file.path.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: item.errorMsg != null
                        ? Text(item.errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 11))
                        : Text(
                            _fileSizes[item.file.path] ?? '',
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: _finished
                  ? OutlinedButton(
                      onPressed: _startBatch,
                      child: const Text('Run Again'),
                    )
                  : FilledButton(
                      onPressed: _running ? null : _startBatch,
                      child: Text(_running ? 'Processing…' : 'Start Batch'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(_FileStatus status, Color primary) {
    switch (status) {
      case _FileStatus.pending:
        return Icon(Icons.schedule_outlined, size: 20, color: Colors.grey.shade400);
      case _FileStatus.processing:
        return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primary));
      case _FileStatus.done:
        return const Icon(Icons.check_circle_outline, size: 20, color: Colors.green);
      case _FileStatus.error:
        return const Icon(Icons.error_outline, size: 20, color: Colors.red);
    }
  }
}
