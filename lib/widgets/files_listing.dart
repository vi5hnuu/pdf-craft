import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/file_selection_config.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:pdf_craft/widgets/confirm_dialog.dart';
import 'package:pdf_craft/widgets/directory_files_listing.dart';

class FilesListing extends StatelessWidget {
  final FileSelectionConfig config;

  const FilesListing({super.key, required this.config});

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
              text: L10n.current.fileDeleteSuccess, color: Colors.green);
        } else if (httpState?.error != null) {
          NotificationService.showSnackbar(
              text: httpState!.error!, color: Colors.red);
        } else if (httpState?.loading == true) {
          NotificationService.showSnackbar(
              text: L10n.current.deletingFile, color: Colors.lightBlue);
        }
      },
      child: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: DirectoryFilesListing(
              excludeShowingDirsPath: config.excludeShowingDirsPath,
              directoryPath: config.path,
              onDelete: (file) => _onDeleteFile(context, file),
            ),
          ),
          const BannerAdd(),
        ],
      ),
    );
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
