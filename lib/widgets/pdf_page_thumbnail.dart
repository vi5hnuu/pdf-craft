import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf_craft/widgets/tool_error_state.dart';
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

  /// Drops any cached renders for [document] — call when a document is closed.
  static void evictDocument(PdfDocument document) {
    final prefix = '${document.id}_';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }
}

// Simple insertion-ordered LRU: cap total cached page bitmaps to bound memory.
const int _maxCached = 80;
final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

/// Physical pixels to rasterise a thumbnail at, rounded up to a 64px bucket so that
/// near-identical sizes share one render instead of each claiming a cache slot.
///
/// Pure and public so the rounding is testable without a document or a platform channel.
/// [logicalWidth] is allowed to be non-finite or zero: a caller inside a grid cell passes
/// `double.infinity` to mean "fill the cell". That used to reach `ceil()`, which throws
/// `UnsupportedError` on a non-finite value, and the throw escaped mid-load and left the
/// thumbnail on a spinner forever. A width we cannot size from yields the floor instead.
@visibleForTesting
int thumbnailTargetPx(double logicalWidth, double devicePixelRatio) {
  const int bucket = 64;
  const int minPx = 64;
  const int maxPx = 2048;
  final wanted = logicalWidth * devicePixelRatio;
  if (!wanted.isFinite || wanted <= 0) return minPx;
  return ((wanted / bucket).ceil() * bucket).clamp(minPx, maxPx);
}

class _PdfPageThumbnailState extends State<PdfPageThumbnail> {
  Uint8List? _bytes;
  bool _error = false;
  bool _loading = false;

  /// Logical width this thumbnail is actually painted at, learned from layout.
  ///
  /// [PdfPageThumbnail.width] may be `double.infinity`: callers inside a grid cell pass it to
  /// mean "fill the cell", which is legitimate but is not a number anything can be rendered at.
  /// The real width is only known once the parent has laid the widget out, so it is resolved in
  /// [build] rather than assumed.
  double? _paintedWidth;

  /// Used when neither the widget nor its constraints give a finite width — an unbounded box.
  /// Small on purpose: the render is upscaled by `BoxFit.cover` rather than being wrong, and
  /// the alternative is guessing large and rasterising a full page for a thumbnail.
  static const double _unboundedFallbackWidth = 120;

  int get _targetPx => thumbnailTargetPx(
      _paintedWidth ?? _unboundedFallbackWidth,
      MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0);

  /// Records the width layout gave us and starts the render once it is known.
  void _resolveWidth(double width) {
    if (_paintedWidth != null && (_paintedWidth! - width).abs() < 1) return;
    final isFirst = _paintedWidth == null;
    _paintedWidth = width;
    // A different width is a different render, so anything already loaded is the wrong size.
    if (!isFirst) {
      _bytes = null;
      _error = false;
    }
    if (_bytes == null && !_error && !_loading) {
      // After the frame: this runs inside build, and _load calls setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  // Keyed on the document's own id, which pdfx generates as a randomUUID() each time a
  // document is opened, so it is unique for the life of the process. identityHashCode was
  // wrong for this: it is a *hash*, so two live documents may share one, and a hash belonging
  // to a collected object can be handed to a later one — either of which would serve one
  // document's page images for another's. Nothing was observed going wrong, but a cache key
  // that is only probably unique is not a cache key.
  //
  // The size is part of the key: the same page shown large and small needs two renders,
  // and without it the first size seen would be stretched to fit the other.
  String get _key => '${widget.document.id}_${widget.pageNumber}_$_targetPx';

  // No didChangeDependencies load: it needs the painted width as well as the device pixel
  // ratio, and the width is not known until layout. build() starts the load instead.


  @override
  void didUpdateWidget(PdfPageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The load above is guarded on `_bytes == null`, which is exactly right for a rebuild and
    // exactly wrong when the element is reused for a different page: the old bitmap is still
    // there, so nothing reloads and the thumbnail shows the wrong page. Call sites that key by
    // page never hit this, but the widget should not depend on every caller remembering to.
    if (oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.document != widget.document) {
      _bytes = null;
      _error = false;
      _loading = false;
      _load();
    }
  }

  Future<void> _load() async {
    _loading = true;
    // Everything is inside the try, and _loading is cleared in the finally. It used to be set
    // before an unguarded expression that could throw, and the guard in the caller then read
    // "already loading" forever — one bad pixel calculation became a permanent spinner.
    try {
      // Captured before anything awaits: _paintedWidth can change mid-flight if the cell is
      // resized, and keying the result by the *new* width would file a bitmap rendered at the
      // old size under it — poisoning that bucket for every thumbnail for the rest of the
      // session.
      final key = _key;
      final cached = _cache[key];
      if (cached != null) {
        if (mounted) setState(() => _bytes = cached);
        return; // already have it — no spinner, no work
      }
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
      _cache[key] = image.bytes;
      if (_cache.length > _maxCached) _cache.remove(_cache.keys.first);
      // Only adopt it if the size it was rendered for is still the size being drawn; otherwise
      // the newer _resolveWidth has already scheduled the right one.
      if (mounted && key == _key) setState(() => _bytes = image.bytes);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder because widget.width is allowed to be double.infinity; the constraints are
    // the only place the painted width can be read, and the render size depends on it.
    return LayoutBuilder(builder: (context, constraints) {
      _resolveWidth(switch (null) {
        _ when widget.width.isFinite => widget.width,
        _ when constraints.maxWidth.isFinite => constraints.maxWidth,
        _ => _unboundedFallbackWidth,
      });
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: _content(),
      );
    });
  }

  Widget _content() {
    // No retry: a page that failed to render inside an already-open document has nothing
    // to retry against, but the cell still owes the user a reason.
    if (_error) return const ToolErrorState(compact: true);
    if (_bytes == null) return const Center(child: CircularProgressIndicator());
    // gaplessPlayback avoids a flicker if the widget rebuilds with new bytes.
    // cacheWidth bounds the decoded texture: without it Flutter decodes the JPEG at
    // its full size regardless of how small it is drawn.
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: _targetPx,
    );
  }
}
