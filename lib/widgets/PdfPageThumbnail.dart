import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Renders a single PDF page as a thumbnail, **rendering each page only once**.
///
/// Previously this used a `FutureBuilder` whose future was recreated on every
/// build, so any parent `setState` (a drag, a checkbox, a counter) re-rendered
/// every visible page and flashed a spinner. Now results are cached in a small
/// process-wide LRU keyed by (document identity, page, size), so rebuilds paint
/// instantly from memory and only the first sighting of a page does real work.
class PdfPageThumbnail extends StatefulWidget {
  final PdfDocument document;
  final int pageNumber;
  final double width;
  final double height;

  const PdfPageThumbnail({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.width,
    required this.height,
  });

  @override
  State<PdfPageThumbnail> createState() => _PdfPageThumbnailState();

  /// Drops any cached renders for [document] — call when a document is closed so
  /// stale bytes for a reused identity hash can't leak into a new document.
  static void evictDocument(PdfDocument document) {
    final prefix = '${identityHashCode(document)}_';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }
}

// Simple insertion-ordered LRU: cap total cached page bitmaps to bound memory.
const int _maxCached = 80;
final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

class _PdfPageThumbnailState extends State<PdfPageThumbnail> {
  Uint8List? _bytes;
  bool _error = false;
  bool _loading = false;

  /// Physical pixels this thumbnail actually occupies, rounded to a bucket so that
  /// near-identical sizes share one render instead of each claiming a cache slot.
  int get _targetPx {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final wanted = widget.width * ratio;
    return ((wanted / 64).ceil() * 64).clamp(64, 2048);
  }

  // The size is part of the key: the same page shown large and small needs two renders,
  // and without it the first size seen would be stretched to fit the other.
  String get _key => '${identityHashCode(widget.document)}_${widget.pageNumber}_$_targetPx';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the device pixel ratio, so it cannot run in initState.
    if (_bytes == null && !_error && !_loading) _load();
  }

  Future<void> _load() async {
    _loading = true;
    final cached = _cache[_key];
    if (cached != null) {
      _bytes = cached;
      _loading = false;
      return; // already have it — no spinner, no work
    }
    try {
      final page = await widget.document.getPage(widget.pageNumber);

      // Render at the size actually shown rather than the page's full size. A page
      // rasterised at its intrinsic dimensions is many times the pixels a thumbnail
      // needs, and every one of them was held in memory and decoded.
      final target = _targetPx.toDouble();
      final width = page.width <= target ? page.width : target;
      final height = page.height / page.width * width;

      final image = await page.render(
        width: width,
        height: height,
        format: PdfPageImageFormat.jpeg,
      );
      await page.close();
      if (image == null) throw Exception('render failed');
      _cache[_key] = image.bytes;
      if (_cache.length > _maxCached) _cache.remove(_cache.keys.first);
      _loading = false;
      if (mounted) setState(() => _bytes = image.bytes);
    } catch (_) {
      _loading = false;
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: Icon(Icons.error, color: Colors.red)),
      );
    }
    if (_bytes == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      // gaplessPlayback avoids a flicker if the widget rebuilds with new bytes.
      // cacheWidth bounds the decoded texture: without it Flutter decodes the JPEG at
      // its full size regardless of how small it is drawn.
      child: Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: _targetPx,
      ),
    );
  }
}
