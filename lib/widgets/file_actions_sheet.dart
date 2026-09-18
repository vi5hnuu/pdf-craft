import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/favorites_service.dart';
import 'package:pdf_craft/state/selection/selection_service.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/widgets/tool_picker_sheet.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_craft/theme/app_radius.dart';

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
      // Without this the sheet runs under the status bar and the display cutout —
      // on a punch-hole phone the top of a tall sheet sits behind the camera.
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.surface))),
      // `context` is the screen that opened this sheet, and it is handed down deliberately: a
      // tool has to be launched from an element that is still in the tree when the launch
      // happens. See [_FileActionsBody.hostContext].
      builder: (_) => _FileActionsBody(
          hostContext: context,
          file: file,
          onChanged: onChanged,
          allowSelect: allowSelect),
    );
  }
}

class _FileActionsBody extends StatefulWidget {
  final File file;
  final VoidCallback? onChanged;

  /// The context of the screen that opened this sheet.
  ///
  /// Needed because launching a tool is asynchronous and outlives this sheet. "Apply a tool"
  /// pops this sheet, opens the picker, and only routes once the user has chosen — by which
  /// point this sheet's own element is long gone. Routing from a defunct element makes
  /// [ToolDef.openWithFiles] return false at its `context.mounted` check, so the sheet closed
  /// and nothing else happened, with no error anywhere. The host screen is still mounted, so it
  /// is what the tool is launched from.
  final BuildContext hostContext;

  /// Show a "Select for tools" entry (only where a selection bar exists to act
  /// on it, e.g. Search). Off on surfaces without a selection bar.
  final bool allowSelect;

  const _FileActionsBody(
      {required this.hostContext,
      required this.file,
      this.onChanged,
      this.allowSelect = false});

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
                    borderRadius: BorderRadius.circular(AppRadius.surface)),
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
              title: Text(_isPdf ? L10n.of(context).actionView : L10n.of(context).openExternally),
              onTap: _view,
            ),
            if (widget.allowSelect)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(SelectionService().contains(widget.file.path)
                    ? L10n.of(context).fileDeselect
                    : L10n.of(context).fileSelectForTools),
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
                  Text(_isFavorite ? L10n.of(context).favRemove : L10n.of(context).favAdd),
              onTap: _toggleFavorite,
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(L10n.of(context).actionShare),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(widget.file.path)]);
              },
            ),
            if (_isPdf)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(L10n.of(context).openInExternalViewer),
                onTap: () {
                  Navigator.pop(context);
                  _openExternally();
                },
              ),
            // One row into the shared picker rather than 47 tiles inlined here. This sheet also
            // carries rename, share and the rest, so the tool list used to bury them.
            if (tools.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.auto_awesome_motion_outlined),
                title: Text(L10n.of(context).applyATool),
                subtitle: Text(L10n.of(context).toolsAvailable(tools.length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final host = widget.hostContext;
                  Navigator.pop(context);
                  ToolPickerSheet.show(
                    host,
                    files: [widget.file],
                    subtitle: widget.file.path.split('/').last,
                    onSelected: (tool) =>
                        unawaited(tool.openWithFiles(host, [widget.file])),
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
