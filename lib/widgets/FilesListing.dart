import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';
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

  _onDeleteFile(BuildContext context, File file) async {
    final theme = Theme.of(context);
    final filename = file.path.split('/').last;
    final inBin = file.path.startsWith(Constants.binDirPath);

    final int? deleteApproved = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Delete File',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    filename,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: theme.dividerColor, height: 1),
              if (!inBin)
                ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.amber.shade600),
                  title: Text(
                    'Move to Bin',
                    style: TextStyle(color: Colors.amber.shade600, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.of(ctx).pop(-1),
                ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Permanent Delete',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                ),
                onTap: () => Navigator.of(ctx).pop(1),
              ),
              ListTile(
                leading: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                title: Text(
                  'Cancel',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(0),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (deleteApproved == -1) {
      BlocProvider.of<FilesBloc>(context)
          .add(MoveFileToEvent(to: Constants.binDirPath, file: file));
    }
    if (deleteApproved == 1) {
      BlocProvider.of<FilesBloc>(context).add(DeleteFileEvent(file: file));
    }
  }
}
