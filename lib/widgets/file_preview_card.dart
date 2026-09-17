import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// A document-style file card used in the Recents / Favorites rows.
///
/// For PDFs it renders the real first-page thumbnail (cached per path so the
/// row scrolls smoothly), giving a true "document" preview rather than a flat
/// icon. The file name is shown below the card and ellipsised on overflow.
class FilePreviewCard extends StatefulWidget {
  final File file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Optional corner badge (e.g. a star for favorites).
  final Widget? badge;

  const FilePreviewCard({
    super.key,
    required this.file,
    required this.onTap,
    this.onLongPress,
    this.badge,
  });

  static const double cardWidth = 104;
  static const double cardHeight = 132;

  @override
  State<FilePreviewCard> createState() => _FilePreviewCardState();
}

class _FilePreviewCardState extends State<FilePreviewCard> {
  /// Thumbnail bytes, keyed by path **and the file's identity on disk**.
  ///
  /// Keying by path alone meant a file rewritten in place — a tool saving over its own output,
  /// a rename back onto a known name — kept the previous page's thumbnail for the rest of the
  /// session. Including mtime and size makes a changed file a cache miss.
  ///
  /// Capped because this map is static and lives for the process: the Files tab scrolls through
  /// the whole device, and every JPEG thumbnail stayed resident forever.
  static final Map<String, Uint8List?> _cache = {};
  static const _cacheLimit = 48;

  Uint8List? _thumb;
  bool _loading = true;

  bool get _isPdf => widget.file.path.toLowerCase().endsWith('.pdf');

  /// Path plus the file's modification time and size, so overwriting invalidates the entry.
  String get _cacheKey {
    try {
      final stat = widget.file.statSync();
      return '${widget.file.path}|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
    } catch (_) {
      // Unreadable/removed: fall back to the path so we still avoid re-rendering in a loop.
      return widget.file.path;
    }
  }

  static void _remember(String key, Uint8List? bytes) {
    // Insertion-ordered, so removing the first key evicts the oldest entry.
    if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
    _cache[key] = bytes;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FilePreviewCard old) {
    super.didUpdateWidget(old);
    // A row is rebuilt with a different file when the listing refreshes; without this the card
    // kept showing the previous file's page.
    if (old.file.path != widget.file.path) {
      setState(() => _loading = true);
      _load();
    }
  }

  Future<void> _load() async {
    final path = _cacheKey;
    if (_cache.containsKey(path)) {
      setState(() {
        _thumb = _cache[path];
        _loading = false;
      });
      return;
    }
    if (!_isPdf) {
      _remember(path, null);
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final page = await doc.getPage(1);
      // Render at a modest width to keep memory/CPU low for a thumbnail.
      const targetWidth = 200.0;
      final targetHeight = page.height / page.width * targetWidth;
      final image = await page.render(
        width: targetWidth,
        height: targetHeight,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      await doc.close();
      _remember(path, image?.bytes);
      if (mounted) {
        setState(() {
          _thumb = image?.bytes;
          _loading = false;
        });
      }
    } catch (_) {
      _remember(path, null);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.file.path.split('/').last;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: FilePreviewCard.cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: FilePreviewCard.cardWidth,
                  height: FilePreviewCard.cardHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.surface),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildPreview(theme),
                ),
                if (widget.badge != null)
                  Positioned(top: 4, right: 4, child: widget.badge!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_thumb != null) {
      return Image.memory(_thumb!,
          fit: BoxFit.cover,
          width: FilePreviewCard.cardWidth,
          height: FilePreviewCard.cardHeight);
    }
    // Fallback: a simple document placeholder (non-PDF or render failed).
    return Center(
      child: Icon(
        _isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file_outlined,
        color: theme.colorScheme.primary,
        size: 40,
      ),
    );
  }
}
