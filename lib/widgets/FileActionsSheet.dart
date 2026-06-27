import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/FavoritesService.dart';
import 'package:pdf_craft/state/selection/SelectionService.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:share_plus/share_plus.dart';

/// A reusable bottom sheet of file-level actions (view, apply a tool, share,
/// favorite, open externally), driven by [ToolRegistry] intellisense so the
/// listed tools actually apply to the file.
///
/// Used wherever a single file is presented (recent/favorite cards, the recents
/// list) so those surfaces offer real app actions instead of just "view".
class FileActionsSheet {
  FileActionsSheet._();

  /// Shows the actions for [file]. [onChanged] is invoked after an action that
  /// may alter the calling list (e.g. toggling favorite) so it can refresh.
  static Future<void> show(
    BuildContext context,
    File file, {
    VoidCallback? onChanged,
    bool allowSelect = false,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FileActionsBody(
          file: file, onChanged: onChanged, allowSelect: allowSelect),
    );
  }
}

class _FileActionsBody extends StatefulWidget {
  final File file;
  final VoidCallback? onChanged;

  /// Show a "Select for tools" entry (only where a selection bar exists to act
  /// on it, e.g. Search). Off on surfaces without a selection bar.
  final bool allowSelect;

  const _FileActionsBody(
      {required this.file, this.onChanged, this.allowSelect = false});

  @override
  State<_FileActionsBody> createState() => _FileActionsBodyState();
}

class _FileActionsBodyState extends State<_FileActionsBody> {
  bool _isFavorite = false;

  String get _name => widget.file.path.split('/').last;
  bool get _isPdf => Utility.isPdf(widget.file.path);

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final fav = await FavoritesService().isFavorite(widget.file.path);
    if (mounted) setState(() => _isFavorite = fav);
  }

  void _view() {
    Navigator.pop(context);
    if (_isPdf) {
      GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,
          pathParameters: {'pdfFilePath': widget.file.path});
    } else {
      _openExternally();
    }
  }

  void _openExternally() {
    final ext = Utility.fileExtension(widget.file);
    OpenFile.open(widget.file.path,
        type: Constants.extrnalOpenSupportedFiles[ext] ?? '*/*');
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService().toggle(widget.file.path);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = ToolRegistry.toolsForSelection([widget.file]);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(_name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(_isPdf ? Icons.visibility : Icons.open_in_new),
              title: Text(_isPdf ? 'View' : 'Open externally'),
              onTap: _view,
            ),
            if (widget.allowSelect)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(SelectionService().contains(widget.file.path)
                    ? 'Deselect'
                    : 'Select for tools'),
                onTap: () {
                  Navigator.pop(context);
                  SelectionService().toggle(widget.file);
                },
              ),
            ListTile(
              leading: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? Colors.amber : null),
              title:
                  Text(_isFavorite ? 'Remove from favorites' : 'Add to favorites'),
              onTap: _toggleFavorite,
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(widget.file.path)]);
              },
            ),
            if (_isPdf)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open in external viewer'),
                onTap: () {
                  Navigator.pop(context);
                  _openExternally();
                },
              ),
            if (tools.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Apply a tool',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
              ...tools.map((tool) => ListTile(
                    leading: Icon(tool.icon, color: tool.category.color),
                    title: Text(tool.name),
                    onTap: () {
                      Navigator.pop(context);
                      tool.openWithFiles(context, [widget.file]);
                    },
                  )),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
