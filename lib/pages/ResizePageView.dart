import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/enums/page-size-preset.dart';
import 'package:pdf_craft/models/request/resize-page.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/utils/ToolViewMixin.dart';
import 'package:pdf_craft/utils/httpStates.dart';

/// Resize Page Size: reflows every page onto a standard size (A4 / Letter /
/// Legal), scaling the content to fit and centering it.
class ResizePageView extends StatefulWidget {
  final File file;
  const ResizePageView({super.key, required this.file});

  @override
  State<ResizePageView> createState() => _ResizePageViewState();
}

class _ResizePageViewState extends State<ResizePageView>
    with ToolResultHandler, ToolViewMixin {
  PageSizePreset _size = PageSizePreset.a4;

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    resetToolState([HttpStates.RESIZE_PAGE]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Resize Page Size')),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.RESIZE_PAGE] != c.httpStates[HttpStates.RESIZE_PAGE],
        listenWhen: (p, c) => p.httpStates[HttpStates.RESIZE_PAGE] != c.httpStates[HttpStates.RESIZE_PAGE],
        listener: (context, state) =>
            handleToolState(state.httpStates[HttpStates.RESIZE_PAGE], successMessage: 'Pages resized'),
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.RESIZE_PAGE]?.loading == true;
          return Stack(children: [
            Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Target size', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    for (final s in PageSizePreset.values)
                      RadioListTile<PageSizePreset>(
                        value: s,
                        groupValue: _size,
                        onChanged: (v) => setState(() => _size = v!),
                        title: Text(s.label),
                        subtitle: Text(s.dimensions),
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
                  onPressed: loading ? null : _onResize,
                  icon: const Icon(Icons.aspect_ratio),
                  label: Text('Resize to ${_size.label}'),
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.RESIZE_PAGE], label: 'Resizing pages'),
          ]);
        },
      ),
    );
  }

  Future<void> _onResize() async {
    final file = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ResizePageEvent(
          resizePage: ResizePage(size: _size, file: file),
          cancelToken: cancelToken,
        ));
  }
}
