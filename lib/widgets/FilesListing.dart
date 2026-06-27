import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';
import 'package:pdf_craft/widgets/ConfirmDialog.dart';
import 'package:pdf_craft/widgets/DirectoryFilesListing.dart';

class FilesListing extends StatelessWidget {
  final FileSelectionConfig config;

  const FilesListing({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return BlocListener<FilesBloc, FilesState>(
      listenWhen: (previous, current) =>
          previous.httpStates[HttpStates.MOVE_FILE_TO] !=
          current.httpStates[HttpStates.MOVE_FILE_TO],
      listener: (context, state) {
        final httpState = state.httpStates[HttpStates.PAGE_NUMBERS];
        if (httpState?.done == true) {
          NotificationService.showSnackbar(
              text: 'File Delete Success.', color: Colors.green);
        } else if (httpState?.error != null) {
          NotificationService.showSnackbar(
              text: httpState!.error!, color: Colors.red);
        } else if (httpState?.loading == true) {
          NotificationService.showSnackbar(
              text: 'Deleting file...', color: Colors.lightBlue);
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
      title: 'Delete File',
      message: 'Permanently delete "$filename"?\nThis cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!result.confirmed || !context.mounted) return;
    BlocProvider.of<FilesBloc>(context).add(DeleteFileEvent(file: file));
  }
}
