import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/favorites_service.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class FileTile extends StatefulWidget {
  final FileSystemEntity file;
  final bool enabled;
  final bool selected;
  final VoidCallback? onPress;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  const FileTile({
    super.key,
    required this.file,
    this.enabled = true,
    this.selected = false,
    this.onPress,
    this.onDelete,
    this.onLongPress,
  });

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  bool _isFavorite = false;
  // Loaded asynchronously to avoid blocking main thread on every build
  String? _sizeStr;
  String? _dateStr;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A ListView reuses this element for whatever file now sits at the same index, so filtering,
    // sorting or changing folder hands the state a different file without rebuilding it. Without
    // this the tile kept the previous file's size, date and star: filtering a folder down to
    // `invoice_form.pdf` showed it as "1.34 KB • 19 Sep", which was the file that had been in
    // that row a moment earlier.
    if (oldWidget.file.path != widget.file.path) {
      // Cleared rather than left in place, so the row shows nothing for the instant before the
      // real values land — never the wrong file's numbers.
      _sizeStr = null;
      _dateStr = null;
      _isFavorite = false;
      _load();
    }
  }

  void _load() {
    if (widget.file is File) {
      _checkFavorite();
      _loadFileMeta();
    }
  }

  Future<void> _checkFavorite() async {
    final fav = await FavoritesService().isFavorite(widget.file.path);
    if (mounted) setState(() => _isFavorite = fav);
  }

  /// Loads size and date asynchronously so build() does no sync IO.
  Future<void> _loadFileMeta() async {
    try {
      final f = widget.file as File;
      final stat = await f.stat();
      final len = await f.length();
      if (!mounted) return;
      final d = stat.modified;
      setState(() {
        _dateStr = '${d.day} ${_months[d.month - 1]} ${d.year}';
        _sizeStr = Utility.bytesToSize(len);
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService().toggle(widget.file.path);
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  /// Shown when a file type has no icon, or has one whose asset is missing.
  ///
  /// Material icons, not FontAwesome: these two glyphs are the only reason the solid and
  /// regular FontAwesome families were referenced at all, and the bundled Material set already
  /// has both. Only the Google brand mark on the sign-in button still needs FontAwesome, so
  /// one family is referenced instead of three.
  ///
  /// Worth being accurate about the size: almost none. Flutter tree-shakes icon fonts — the
  /// release build reduces the brands family from 215 KB to 1.4 KB — so three families each
  /// carrying one glyph already cost about what one does. This is a dependency-surface change,
  /// not the ~476 KB saving it first looks like.
  Widget _genericIcon(Color primary) => Icon(
        widget.file is Directory ? Icons.folder : Icons.insert_drive_file,
        color: primary,
        size: 22,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fileIcon = Constants.fileIcons[
        widget.file is Directory ? 'folder' : widget.file.path.split('.').last];

    Widget? trailing;
    if (widget.file is File) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            tooltip: _isFavorite ? L10n.of(context).favRemove : L10n.of(context).favAdd,
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: widget.onDelete,
              tooltip: L10n.of(context).delete,
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            ),
        ],
      );
    } else {
      trailing = Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.surface)),
      child: ListTile(
        enabled: widget.enabled,
        selected: widget.selected,
        selectedTileColor: primary.withValues(alpha: 0.12),
        selectedColor: primary,
        // Keep the leading icon vertically centered even when a subtitle is
        // present (otherwise it floats to the top on two-line tiles).
        titleAlignment: ListTileTitleAlignment.center,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          child: fileIcon != null
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  // errorBuilder because a mapping can outlive its asset: 'doc' pointed at a
                  // file that was never bundled, and with no builder Flutter paints its grey
                  // exception box in the middle of the list. Falling back to the generic icon
                  // keeps a missing asset cosmetic rather than making the row look broken.
                  child: Image.asset(
                    fileIcon,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _genericIcon(primary),
                  ),
                )
              : _genericIcon(primary),
        ),
        title: Text(
          widget.file.path.split('/').last,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: widget.file is File && _sizeStr != null && _dateStr != null
            ? Text(
                '$_sizeStr  •  $_dateStr',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              )
            : null,
        trailing: trailing,
        onTap: widget.onPress,
        onLongPress: widget.onLongPress,
      ),
    );
  }
}
