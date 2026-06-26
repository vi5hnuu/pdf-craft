import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf_craft/singletons/FavoritesService.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';

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
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: widget.onDelete,
              icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        enabled: widget.enabled,
        selected: widget.selected,
        selectedTileColor: primary.withValues(alpha: 0.12),
        selectedColor: primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: fileIcon != null
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(fileIcon, fit: BoxFit.contain),
                )
              : FaIcon(
                  widget.file is Directory
                      ? FontAwesomeIcons.solidFolder
                      : FontAwesomeIcons.file,
                  color: primary,
                  size: 20,
                ),
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
