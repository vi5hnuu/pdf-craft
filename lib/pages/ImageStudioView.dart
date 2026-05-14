import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/image-studio.dart' as img_studio;
import 'package:pdf_craft/models/request/filter-image.dart' as fi;
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

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
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    AdsSingleton().dispatch(LoadInterstitialAd());
    _tabC = TabController(length: 5, vsync: this, initialIndex: widget.op.index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Studio'),
        bottom: TabBar(
          controller: _tabC,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.compress), text: 'Compress'),
            Tab(icon: Icon(Icons.image), text: 'To JPG'),
            Tab(icon: Icon(Icons.swap_horiz), text: 'From JPG'),
            Tab(icon: Icon(Icons.photo_size_select_large), text: 'Resize'),
            Tab(icon: Icon(Icons.auto_fix_high), text: 'Filters'),
          ],
        ),
      ),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) =>
            p.httpStates[HttpStates.IMAGE_STUDIO] != c.httpStates[HttpStates.IMAGE_STUDIO] ||
            p.httpStates[HttpStates.FILTER_IMAGE] != c.httpStates[HttpStates.FILTER_IMAGE],
        listenWhen: (p, c) =>
            p.httpStates[HttpStates.IMAGE_STUDIO] != c.httpStates[HttpStates.IMAGE_STUDIO] ||
            p.httpStates[HttpStates.FILTER_IMAGE] != c.httpStates[HttpStates.FILTER_IMAGE],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.IMAGE_STUDIO];
          if (s?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Image saved to processed folder', color: Colors.green);
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Processing image…', color: Colors.lightBlue);
          }
          final fs = state.httpStates[HttpStates.FILTER_IMAGE];
          if (fs?.done == true) {
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: 'Filtered image saved', color: Colors.green);
          } else if (fs?.error != null) {
            NotificationService.showSnackbar(text: fs!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          final loading = state.httpStates[HttpStates.IMAGE_STUDIO]?.loading == true ||
              state.httpStates[HttpStates.FILTER_IMAGE]?.loading == true;
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
                      '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
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
            LoadingOverlay(httpState: state.httpStates[HttpStates.IMAGE_STUDIO] ?? state.httpStates[HttpStates.FILTER_IMAGE]),
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
        Text('JPEG Quality: $_compressQuality%', style: theme.textTheme.bodyMedium),
        Slider(
          value: _compressQuality.toDouble(),
          min: 1, max: 100, divisions: 99,
          onChanged: (v) => setState(() => _compressQuality = v.round()),
        ),
        const SizedBox(height: 8),
        _qualityHint(theme, _compressQuality),
        const Spacer(),
        _submitButton(loading, 'Compress Image', Icons.compress, _onCompress),
      ]),
    );
  }

  Widget _qualityHint(ThemeData theme, int quality) {
    final hint = quality >= 90 ? 'High quality — minimal compression'
        : quality >= 70 ? 'Good balance of quality and size'
        : quality >= 50 ? 'Noticeable compression — smaller file'
        : 'Aggressive compression — smallest file';
    return Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }

  // ── Convert to JPG tab ────────────────────────────────────────────────────────

  Widget _buildToJpgTab(ThemeData theme, bool loading) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Output JPEG Quality: $_toJpgQuality%', style: theme.textTheme.bodyMedium),
        Slider(
          value: _toJpgQuality.toDouble(),
          min: 1, max: 100, divisions: 99,
          onChanged: (v) => setState(() => _toJpgQuality = v.round()),
        ),
        const SizedBox(height: 8),
        _qualityHint(theme, _toJpgQuality),
        const SizedBox(height: 8),
        Text(
          'PNG and other images with transparency will be composited on a white background.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outlineVariant),
        ),
        const Spacer(),
        _submitButton(loading, 'Convert to JPG', Icons.image, _onConvertToJpg),
      ]),
    );
  }

  // ── Convert from JPG tab ──────────────────────────────────────────────────────

  Widget _buildFromJpgTab(ThemeData theme, bool loading) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Target Format', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          _formatChip('PNG', theme),
          const SizedBox(width: 12),
          _formatChip('BMP', theme),
        ]),
        const SizedBox(height: 12),
        Text(
          'PNG supports transparency and is lossless. BMP is uncompressed.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outlineVariant),
        ),
        const Spacer(),
        _submitButton(loading, 'Convert from JPG', Icons.swap_horiz, _onConvertFromJpg),
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
              decoration: const InputDecoration(labelText: 'Width (px)', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _heightC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (px)', border: OutlineInputBorder()),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Switch(value: _maintainAspect, onChanged: (v) => setState(() => _maintainAspect = v)),
          const SizedBox(width: 8),
          const Text('Maintain aspect ratio'),
        ]),
        if (_maintainAspect)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Enter only one dimension — the other is computed proportionally.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outlineVariant),
            ),
          ),
        const Spacer(),
        _submitButton(loading, 'Resize Image', Icons.photo_size_select_large, _onResize),
      ]),
    );
  }

  // ── Filter tab ────────────────────────────────────────────────────────────────

  static const _filterLabels = <fi.ImageFilterType, String>{
    fi.ImageFilterType.grayscale: 'Grayscale',
    fi.ImageFilterType.sepia: 'Sepia',
    fi.ImageFilterType.sharpen: 'Sharpen',
    fi.ImageFilterType.brightness: 'Brightness',
    fi.ImageFilterType.contrast: 'Contrast',
    fi.ImageFilterType.vintage: 'Vintage',
  };

  Widget _buildFilterTab(ThemeData theme, bool loading) {
    final showIntensity = _filterType != fi.ImageFilterType.grayscale &&
        _filterType != fi.ImageFilterType.sharpen;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Filter', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: fi.ImageFilterType.values.map((type) => ChoiceChip(
            label: Text(_filterLabels[type] ?? type.name),
            selected: _filterType == type,
            onSelected: (_) => setState(() => _filterType = type),
          )).toList(),
        ),
        if (showIntensity) ...[
          const SizedBox(height: 16),
          Text('Intensity: ${_filterIntensity.toStringAsFixed(1)}',
              style: theme.textTheme.bodyMedium),
          Slider(
            value: _filterIntensity,
            min: 0, max: 2, divisions: 20,
            onChanged: (v) => setState(() => _filterIntensity = v),
          ),
        ],
        const Spacer(),
        _submitButton(loading, 'Apply Filter', Icons.auto_fix_high, _onFilter),
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
    BlocProvider.of<PdfBloc>(context).add(CompressImageEvent(
      compressImage: img_studio.CompressImage(
        quality: _compressQuality,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  Future<void> _onConvertToJpg() async {
    BlocProvider.of<PdfBloc>(context).add(ConvertToJpgEvent(
      convertToJpg: img_studio.ConvertToJpg(
        quality: _toJpgQuality,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  Future<void> _onConvertFromJpg() async {
    BlocProvider.of<PdfBloc>(context).add(ConvertFromJpgEvent(
      convertFromJpg: img_studio.ConvertFromJpg(
        format: _fromJpgFormat,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  Future<void> _onFilter() async {
    BlocProvider.of<PdfBloc>(context).add(FilterImageEvent(
      filterImage: fi.FilterImage(
        filterType: _filterType,
        intensity: _filterIntensity,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  Future<void> _onResize() async {
    final w = int.tryParse(_widthC.text.trim());
    final h = int.tryParse(_heightC.text.trim());
    if (w == null && h == null) {
      NotificationService.showSnackbar(text: 'Enter at least one dimension', color: Colors.orange);
      return;
    }
    BlocProvider.of<PdfBloc>(context).add(ResizeImageEvent(
      resizeImage: img_studio.ResizeImage(
        width: w,
        height: h,
        maintainAspectRatio: _maintainAspect,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _tabC.dispose();
    _widthC.dispose();
    _heightC.dispose();
    super.dispose();
  }
}
