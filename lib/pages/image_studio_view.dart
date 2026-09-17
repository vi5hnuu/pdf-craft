import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/image_studio.dart' as img_studio;
import 'package:pdf_craft/models/request/filter_image.dart' as fi;
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';

/// Unified Image Studio view: compress, convert to/from JPG, and resize.
/// The [op] parameter selects the initial tab.
class ImageStudioView extends StatefulWidget {
  final File file;
  final img_studio.ImageStudioOp op;

  const ImageStudioView({super.key, required this.file, required this.op});

  @override
  State<ImageStudioView> createState() => _ImageStudioViewState();
}

class _ImageStudioViewState extends State<ImageStudioView>
    with SingleTickerProviderStateMixin, ToolResultHandler, ToolViewMixin {
  late TabController _tabC;

  // Compress
  int _compressQuality = 75;
  // Convert to JPG
  int _toJpgQuality = 90;
  // Convert from JPG
  String _fromJpgFormat = 'PNG';
  // Resize
  final _widthC = TextEditingController();
  final _heightC = TextEditingController();
  bool _maintainAspect = true;
  // Filter
  fi.ImageFilterType _filterType = fi.ImageFilterType.grayscale;
  double _filterIntensity = 1.0;

  String _sizeLabel = '';

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _tabC = TabController(length: 5, vsync: this, initialIndex: widget.op.index);
    try {
      _sizeLabel = '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB';
    } catch (_) {}
    resetToolState([HttpStates.filterImage, HttpStates.imageStudio]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).toolCatImageStudio),
        bottom: TabBar(
          controller: _tabC,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.compress), text: L10n.of(context).tabCompress),
            Tab(icon: const Icon(Icons.image), text: L10n.of(context).tabToJpg),
            Tab(icon: const Icon(Icons.swap_horiz), text: L10n.of(context).tabFromJpg),
            Tab(icon: const Icon(Icons.photo_size_select_large), text: L10n.of(context).tabResize),
            Tab(icon: const Icon(Icons.auto_fix_high), text: L10n.of(context).tabFilters),
          ],
        ),
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.imageStudio] != c.httpStates[HttpStates.imageStudio] ||
            p.httpStates[HttpStates.filterImage] != c.httpStates[HttpStates.filterImage],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.imageStudio] != c.httpStates[HttpStates.imageStudio] ||
            p.httpStates[HttpStates.filterImage] != c.httpStates[HttpStates.filterImage],
        // The result is an image saved to the processed folder, so there is nothing to navigate
        // to; onDone with no body keeps the user on the tab they were working in.
        //
        // Each key is cleared once handled. Both are inspected on every state change, so a key
        // left sitting at done:true from an earlier run announced itself again every time the
        // other one finished — run a filter, then a compress, and "Filtered image saved"
        // appeared a second time.
        listener: (context, state) {
          for (final entry in {
            HttpStates.imageStudio: L10n.current.imageSaved,
            HttpStates.filterImage: L10n.current.filteredImageSaved,
          }.entries) {
            final s = state.httpStates[entry.key];
            if (s?.done != true && s?.error == null) continue;
            handleToolState(s, successMessage: entry.value, onDone: (_) {});
            resetToolState([entry.key]);
          }
        },
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.imageStudio]?.loading == true ||
              state.httpStates[HttpStates.filterImage]?.loading == true;
          return Stack(children: [
            Column(children: [
              // File info card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      _sizeLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabC,
                  children: [
                    _buildCompressTab(theme, loading),
                    _buildToJpgTab(theme, loading),
                    _buildFromJpgTab(theme, loading),
                    _buildResizeTab(theme, loading),
                    _buildFilterTab(theme, loading),
                  ],
                ),
              ),
            ]),
            processingOverlay(state.httpStates[HttpStates.imageStudio] ?? state.httpStates[HttpStates.filterImage], label: L10n.of(context).procWorking),
          ]);
        },
      ),
    );
  }

  // ── Compress tab ─────────────────────────────────────────────────────────────

  Widget _buildCompressTab(ThemeData theme, bool loading) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L10n.of(context).jpegQuality(_compressQuality), style: theme.textTheme.bodyMedium),
        Slider(
          value: _compressQuality.toDouble(),
          min: 1, max: 100, divisions: 99,
          onChanged: (v) => setState(() => _compressQuality = v.round()),
        ),
        const SizedBox(height: 8),
        _qualityHint(theme, _compressQuality),
        const Spacer(),
        _submitButton(loading, ToolStrings.name(context, 'img-compress'), Icons.compress, _onCompress),
      ]),
    );
  }

  Widget _qualityHint(ThemeData theme, int quality) {
    final hint = quality >= 90 ? L10n.of(context).qualityHigh
        : quality >= 70 ? L10n.of(context).qualityBalanced
        : quality >= 50 ? L10n.of(context).qualityNoticeable
        : L10n.of(context).qualityAggressive;
    return Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }

  // ── Convert to JPG tab ────────────────────────────────────────────────────────

  Widget _buildToJpgTab(ThemeData theme, bool loading) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L10n.of(context).outputJpegQuality(_toJpgQuality), style: theme.textTheme.bodyMedium),
        Slider(
          value: _toJpgQuality.toDouble(),
          min: 1, max: 100, divisions: 99,
          onChanged: (v) => setState(() => _toJpgQuality = v.round()),
        ),
        const SizedBox(height: 8),
        _qualityHint(theme, _toJpgQuality),
        const SizedBox(height: 8),
        Text(
          L10n.of(context).jpgTransparencyNote,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outlineVariant),
        ),
        const Spacer(),
        _submitButton(loading, ToolStrings.name(context, 'img-to-jpg'), Icons.image, _onConvertToJpg),
      ]),
    );
  }

  // ── Convert from JPG tab ──────────────────────────────────────────────────────

  Widget _buildFromJpgTab(ThemeData theme, bool loading) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L10n.of(context).targetFormat, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          _formatChip('PNG', theme),
          const SizedBox(width: 12),
          _formatChip('BMP', theme),
        ]),
        const SizedBox(height: 12),
        Text(
          L10n.of(context).fromJpgNote,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outlineVariant),
        ),
        const Spacer(),
        _submitButton(loading, ToolStrings.name(context, 'img-from-jpg'), Icons.swap_horiz, _onConvertFromJpg),
      ]),
    );
  }

  Widget _formatChip(String label, ThemeData theme) {
    final selected = _fromJpgFormat == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _fromJpgFormat = label),
    );
  }

  // ── Resize tab ────────────────────────────────────────────────────────────────

  Widget _buildResizeTab(ThemeData theme, bool loading) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _widthC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: L10n.of(context).widthPx, border: const OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _heightC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: L10n.of(context).heightPx, border: const OutlineInputBorder()),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Switch(value: _maintainAspect, onChanged: (v) => setState(() => _maintainAspect = v)),
          const SizedBox(width: 8),
          Text(L10n.of(context).maintainAspect),
        ]),
        if (_maintainAspect)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              L10n.of(context).resizeOneDimensionNote,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outlineVariant),
            ),
          ),
        const Spacer(),
        _submitButton(loading, ToolStrings.name(context, 'img-resize'), Icons.photo_size_select_large, _onResize),
      ]),
    );
  }

  // ── Filter tab ────────────────────────────────────────────────────────────────

  /// Filter names, localized at call time — a const map cannot hold them because the strings
  /// depend on the active locale.
  String _filterLabel(BuildContext context, fi.ImageFilterType type) => switch (type) {
        fi.ImageFilterType.grayscale => L10n.of(context).filterGrayscale,
        fi.ImageFilterType.sepia => L10n.of(context).filterSepia,
        fi.ImageFilterType.sharpen => L10n.of(context).filterSharpen,
        fi.ImageFilterType.brightness => L10n.of(context).filterBrightness,
        fi.ImageFilterType.contrast => L10n.of(context).filterContrast,
        fi.ImageFilterType.vintage => L10n.of(context).filterVintage,
      };


  Widget _buildFilterTab(ThemeData theme, bool loading) {
    final showIntensity = _filterType != fi.ImageFilterType.grayscale &&
        _filterType != fi.ImageFilterType.sharpen;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L10n.of(context).filterLabel, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: fi.ImageFilterType.values.map((type) => ChoiceChip(
            label: Text(_filterLabel(context, type)),
            selected: _filterType == type,
            onSelected: (_) => setState(() => _filterType = type),
          )).toList(),
        ),
        if (showIntensity) ...[
          const SizedBox(height: 16),
          Text(L10n.of(context).intensity(_filterIntensity.toStringAsFixed(1)),
              style: theme.textTheme.bodyMedium),
          Slider(
            value: _filterIntensity,
            min: 0, max: 2, divisions: 20,
            onChanged: (v) => setState(() => _filterIntensity = v),
          ),
        ],
        const Spacer(),
        _submitButton(loading, L10n.of(context).applyFilter, Icons.auto_fix_high, _onFilter),
      ]),
    );
  }

  // ── Shared submit button ──────────────────────────────────────────────────────

  Widget _submitButton(bool loading, String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(label),
      ),
    );
  }

  // ── Submit handlers ───────────────────────────────────────────────────────────

  Future<void> _onCompress() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => CompressImageEvent(
      compressImage: img_studio.CompressImage(
        quality: _compressQuality,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  Future<void> _onConvertToJpg() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ConvertToJpgEvent(
      convertToJpg: img_studio.ConvertToJpg(
        quality: _toJpgQuality,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  Future<void> _onConvertFromJpg() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ConvertFromJpgEvent(
      convertFromJpg: img_studio.ConvertFromJpg(
        format: _fromJpgFormat,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  Future<void> _onFilter() async {
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => FilterImageEvent(
      filterImage: fi.FilterImage(
        filterType: _filterType,
        intensity: _filterIntensity,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  Future<void> _onResize() async {
    final w = int.tryParse(_widthC.text.trim());
    final h = int.tryParse(_heightC.text.trim());
    if (w == null && h == null) {
      NotificationService.showSnackbar(text: L10n.current.enterDimension, color: Colors.orange);
      return;
    }
    final uploadFile = await MultipartFile.fromFile(widget.file.path);
    if (!mounted) return;
    runTool((cancelToken) => ResizeImageEvent(
      resizeImage: img_studio.ResizeImage(
        width: w,
        height: h,
        maintainAspectRatio: _maintainAspect,
        file: uploadFile,
      ), cancelToken: cancelToken));
  }

  @override
  void dispose() {
    _tabC.dispose();
    _widthC.dispose();
    _heightC.dispose();
    super.dispose();
  }
}
