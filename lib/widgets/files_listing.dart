import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/file_selection_config.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/utils/responsive.dart';
import 'package:pdf_craft/widgets/pdf_preview.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:pdf_craft/widgets/confirm_dialog.dart';
import 'package:pdf_craft/widgets/directory_files_listing.dart';

/// Browsing a directory, with the selected PDF shown beside the list where there is room for it.
class FilesListing extends StatefulWidget {
  final FileSelectionConfig config;

  const FilesListing({super.key, required this.config});

  @override
  State<FilesListing> createState() => _FilesListingState();
}

class _FilesListingState extends State<FilesListing> {
  /// Width given to the list when the preview sits beside it.
  static const double _listPaneWidth = 380;

  /// The PDF in the preview pane, or null for the empty state. Kept when the window narrows to
  /// one pane, so widening again restores it — a resize should not navigate anywhere by itself.
  String? _previewPath;

  /// Whether the preview pane is actually on screen, as opposed to merely remembered.
  ///
  /// The selection survives a narrowing so widening restores it, which means _previewPath can be
  /// set while only the list is rendered. Back must not be intercepted then: there is nothing
  /// visible to close, and swallowing the press made the user press twice to leave the folder.
  bool _previewVisible = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<FilesBloc, FilesState>(
      listenWhen: (previous, current) =>
          previous.httpStates[HttpStates.moveFileTo] !=
          current.httpStates[HttpStates.moveFileTo],
      listener: (context, state) {
        final httpState = state.httpStates[HttpStates.pageNumbers];
        if (httpState?.done == true) {
          NotificationService.showSnackbar(
              text: L10n.current.fileDeleteSuccess, kind: SnackKind.success);
        } else if (httpState?.error != null) {
          NotificationService.showSnackbar(
              text: httpState!.error!, kind: SnackKind.error);
        } else if (httpState?.loading == true) {
          NotificationService.showSnackbar(
              text: L10n.current.deletingFile, kind: SnackKind.info);
        }
      },
      // PopScope so back closes the preview before it leaves the screen. In two pane nothing
      // was pushed, so without this the first back would exit the directory while a document
      // was still on show.
      child: PopScope(
        canPop: !_previewVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _previewPath = null);
        },
        child: Column(
          children: [
            Expanded(
              // The pane's own width, not the window's: beside a navigation rail this is about
              // 80dp narrower, which is enough to change the answer.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoPane =
                      windowSizeFor(constraints.maxWidth) == WindowSize.expanded;
                  final showingPreview = twoPane && _previewPath != null;
                  if (showingPreview != _previewVisible) {
                    // After the frame: this runs during layout, and PopScope only needs the
                    // new value from the next press onwards.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _previewVisible = showingPreview);
                    });
                  }
                  return twoPane ? _twoPane(context) : _listing(context);
                },
              ),
            ),
            const BannerAdd(),
          ],
        ),
      ),
    );
  }

  Widget _twoPane(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: _listPaneWidth, child: _listing(context, inPane: true)),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _previewPane(context)),
      ],
    );
  }

  Widget _listing(BuildContext context, {bool inPane = false}) {
    return DirectoryFilesListing(
      excludeShowingDirsPath: widget.config.excludeShowingDirsPath,
      directoryPath: widget.config.path,
      onDelete: (file) => _onDeleteFile(context, file),
      // Only in two pane. Left null otherwise so a single-pane tap still pushes the full
      // screen preview exactly as before.
      onOpenPdf: inPane ? (file) => setState(() => _previewPath = file.path) : null,
    );
  }

  Widget _previewPane(BuildContext context) {
    final path = _previewPath;
    if (path == null) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(L10n.of(context).filesSelectToPreview,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      );
    }
    // Keyed by path so a new selection builds fresh state rather than reusing a controller
    // still holding the previous document.
    return PdfPreview(key: ValueKey(path), pdfFilePath: path, embedded: true);
  }

  // Deletion is permanent now that the Bin has been removed, so it is always
  // guarded by a destructive confirmation warning.
  _onDeleteFile(BuildContext context, File file) async {
    final filename = file.path.split('/').last;
    final result = await ConfirmDialog.show(
      context,
      title: L10n.current.deleteFileTitle,
      message: L10n.current.confirmDeleteFile(filename),
      confirmLabel: L10n.current.delete,
      destructive: true,
    );
    if (!result.confirmed || !context.mounted) return;
    BlocProvider.of<FilesBloc>(context).add(DeleteFileEvent(file: file));
  }
}
