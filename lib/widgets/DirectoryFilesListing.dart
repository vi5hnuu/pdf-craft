import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/FileTile.dart';
import 'package:open_file/open_file.dart';

enum _SortMode { name, date, size }

class DirectoryFilesListing extends StatefulWidget {
  final String directoryPath;
  final bool? multiSelect;
  final List<String> limitSelectionToExtensions;
  final int? minSelection;
  final Function(List<File>)? onDoneSelection;
  final Function(File)? onDelete;
  final List<String>? excludeShowingDirsPath;

  DirectoryFilesListing(
      {super.key,
      required this.directoryPath,
      this.multiSelect,
      this.limitSelectionToExtensions = const [],
      this.onDoneSelection,
      this.minSelection,
      this.onDelete,
      this.excludeShowingDirsPath}) {
    if (multiSelect == null &&
        (onDoneSelection != null || minSelection != null)) {
      throw Exception(
          "multiSelect is disabled but onDownSelection/minSelection is not null");
    }
    if (multiSelect != null && onDoneSelection == null) {
      throw Exception("OnDoneSelection is required");
    }
  }

  @override
  State<DirectoryFilesListing> createState() => _DirectoryFilesListingState();
}

class _DirectoryFilesListingState extends State<DirectoryFilesListing> {
  late final FilesBloc bloc;
  final List<File> selectedFiles = [];
  List<String> pathToDirectory = [];
  List<File> deletedFiles = [];
  _SortMode _sortMode = _SortMode.name;

  @override
  void initState() {
    bloc = BlocProvider.of<FilesBloc>(context);
    pathToDirectory = [widget.directoryPath];
    _loadDirectoryFiles(pathToDirectory.last);
    super.initState();
  }

  List<FileSystemEntity> _sortedFiles(List<FileSystemEntity> files) {
    final dirs = files.whereType<Directory>().toList();
    final regularFiles = files.whereType<File>().toList();

    switch (_sortMode) {
      case _SortMode.name:
        dirs.sort((a, b) => a.path
            .split('/')
            .last
            .toLowerCase()
            .compareTo(b.path.split('/').last.toLowerCase()));
        regularFiles.sort((a, b) => a.path
            .split('/')
            .last
            .toLowerCase()
            .compareTo(b.path.split('/').last.toLowerCase()));
      case _SortMode.date:
        dirs.sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
        regularFiles.sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
      case _SortMode.size:
        dirs.sort((a, b) => 0);
        regularFiles.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
    }

    return [...dirs, ...regularFiles];
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (pathToDirectory.length <= 1) {
          router.pop();
        } else {
          setState(() {
            pathToDirectory.removeLast();
            _loadDirectoryFiles(pathToDirectory.last);
          });
        }
      },
      child: BlocConsumer<FilesBloc, FilesState>(
        listener: (context, state) {
          final error = state.getError(forr: HttpStates.LOAD_DIRECTORY_FILES);
          if (error != null) {
            NotificationService.showSnackbar(
                text: error, color: Colors.red);
            setState(() => pathToDirectory.removeLast());
            if (pathToDirectory.isEmpty) router.pop();
          }
        },
        buildWhen: (previous, current) => previous != current,
        listenWhen: (previous, current) => previous != current,
        builder: (context, state) {
          return Stack(children: [
            if (!state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES))
              (state.files.isEmpty
                  ? const Center(child: Text('No files found'))
                  : Flex(
                      direction: Axis.vertical,
                      children: [
                        _buildBreadcrumbAndSort(theme, primary),
                        Flexible(
                          fit: FlexFit.tight,
                          child: ListView.builder(
                            itemCount:
                                _sortedFiles(state.files).length,
                            itemBuilder: (context, index) {
                              final file =
                                  _sortedFiles(state.files)[index];

                              if ((file is Directory) &&
                                  widget.excludeShowingDirsPath
                                          ?.contains(file.path) ==
                                      true) {
                                return const SizedBox.shrink();
                              }

                              if (deletedFiles.contains(file)) {
                                if (state.isLoading(
                                        forr: HttpStates.DELETE_FILE) ||
                                    state.isLoading(
                                        forr: HttpStates.MOVE_FILE_TO) ||
                                    !file.existsSync()) {
                                  return const SizedBox.shrink();
                                }
                                deletedFiles.remove(file);
                              }
                              return FileTile(
                                file: file,
                                selected: _isFileSelected(file),
                                onPress: () => _onItemClick(file: file),
                                onLongPress: () => _showContextMenu(file),
                                onDelete: widget.onDelete != null &&
                                        file is File
                                    ? () {
                                        widget.onDelete!(file);
                                        deletedFiles.add(file);
                                      }
                                    : null,
                                enabled: file is Directory ||
                                    widget.limitSelectionToExtensions
                                        .isEmpty ||
                                    widget.limitSelectionToExtensions.contains(
                                        Utility.fileExtension(file as File)),
                              );
                            },
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: selectedFiles.isNotEmpty ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: selectedFiles.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  width: double.infinity,
                                  color: theme.scaffoldBackgroundColor,
                                  child: FilledButton(
                                    onPressed: widget.onDoneSelection == null ||
                                            (widget.minSelection != null &&
                                                selectedFiles.length <
                                                    widget.minSelection!)
                                        ? null
                                        : () => widget
                                            .onDoneSelection!(selectedFiles),
                                    child:
                                        const Text('Complete Selection'),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    )),
            if (state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES))
              Container(
                decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8)),
                child: Align(
                  alignment: Alignment.center,
                  child: SpinKitRipple(size: 72, color: primary),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _buildBreadcrumbAndSort(ThemeData theme, Color primary) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < pathToDirectory.length; i++) ...[
                  if (i > 0)
                    Icon(Icons.chevron_right,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  GestureDetector(
                    onTap: i < pathToDirectory.length - 1
                        ? () {
                            setState(() {
                              pathToDirectory =
                                  pathToDirectory.sublist(0, i + 1);
                              _loadDirectoryFiles(pathToDirectory.last);
                            });
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: i == pathToDirectory.length - 1
                            ? primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pathToDirectory[i].split('/').last.isEmpty
                            ? 'Root'
                            : pathToDirectory[i].split('/').last,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == pathToDirectory.length - 1
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: i == pathToDirectory.length - 1
                              ? primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Sort:',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const SizedBox(width: 4),
              ..._SortMode.values.map((mode) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _sortMode = mode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _sortMode == mode
                              ? primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _sortMode == mode
                                ? primary
                                : theme.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          mode.name[0].toUpperCase() +
                              mode.name.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _sortMode == mode
                                ? primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  bool _isFileSelected(FileSystemEntity file) {
    if (file is Directory) return false;
    try {
      return selectedFiles
              .firstWhere((selectedFile) => selectedFile.path == file.path) !=
          null;
    } catch (e) {
      return false;
    }
  }

  _loadDirectoryFiles(String path) {
    if (bloc.state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES)) return;
    bloc.add(LoadDirectoryFilesEvent(path: pathToDirectory.last));
  }

  // Shows a bottom sheet with rename (and future actions) for long-pressed items
  void _showContextMenu(FileSystemEntity file) {
    final isDir = file is Directory;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                file.path.split('/').last,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Rename ${isDir ? 'Folder' : 'File'}'),
              onTap: () {
                Navigator.pop(context);
                _renameFile(file);
              },
            ),
            if (!isDir) ...[
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy to…'),
                onTap: () {
                  Navigator.pop(context);
                  _copyOrMove(file as File, move: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to…'),
                onTap: () {
                  Navigator.pop(context);
                  _copyOrMove(file as File, move: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('File Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showFileInfo(file as File);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(File file) {
    final stat = file.statSync();
    final name = file.path.split('/').last;
    final size = Utility.bytesToSize(file.lengthSync());
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String fmt(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
              const Divider(height: 24),
              _infoRow(Icons.folder_outlined, 'Path', file.path),
              const SizedBox(height: 12),
              _infoRow(Icons.data_usage_outlined, 'Size', size),
              const SizedBox(height: 12),
              _infoRow(Icons.schedule_outlined, 'Modified', fmt(stat.modified)),
              const SizedBox(height: 12),
              _infoRow(Icons.add_circle_outline, 'Created', fmt(stat.changed)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ],
    );
  }

  // Opens a folder picker and then copies or moves [file] to the chosen directory.
  Future<void> _copyOrMove(File file, {required bool move}) async {
    final destDir = await showDialog<String>(
      context: context,
      builder: (_) => _FolderPickerDialog(startPath: Constants.rootStoragePath),
    );
    if (destDir == null || !mounted) return;

    final fileName = file.path.split('/').last;
    final destPath = '$destDir/$fileName';

    try {
      if (move) {
        await file.rename(destPath);
        NotificationService.showSnackbar(text: 'Moved to $destDir', color: Colors.green);
      } else {
        await file.copy(destPath);
        NotificationService.showSnackbar(text: 'Copied to $destDir', color: Colors.green);
      }
      _loadDirectoryFiles(pathToDirectory.last);
    } catch (e) {
      NotificationService.showSnackbar(text: 'Operation failed', color: Colors.red);
    }
  }

  // Shows rename dialog and renames the file/directory on the filesystem
  void _renameFile(FileSystemEntity entity) async {
    final currentName = entity.path.split('/').last;
    // Strip extension so user edits just the base name for files
    final isFile = entity is File;
    final ext = isFile ? '.${currentName.split('.').last}' : '';
    final baseName = isFile && currentName.contains('.') ? currentName.substring(0, currentName.lastIndexOf('.')) : currentName;

    final controller = TextEditingController(text: baseName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename ${isFile ? 'File' : 'Folder'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'New name',
            suffixText: ext,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == baseName) return;

    try {
      final dir = entity.parent.path;
      final newPath = '$dir/$newName$ext';
      await entity.rename(newPath);
      // Refresh listing
      _loadDirectoryFiles(pathToDirectory.last);
      NotificationService.showSnackbar(text: 'Renamed successfully', color: Colors.green);
    } catch (e) {
      NotificationService.showSnackbar(text: 'Failed to rename', color: Colors.red);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  _onItemClick({required FileSystemEntity file}) async {
    try {
      if (file is Directory) {
        _loadDirectoryFiles((pathToDirectory..add(file.path)).last);
        return;
      }

      if (widget.multiSelect == null) {
        if (Utility.isPdf(file.path)) {
          GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,
              pathParameters: {'pdfFilePath': file.path});
        } else {
          OpenFile.open(file.path,
              type: Constants.extrnalOpenSupportedFiles[
                      Utility.fileExtension(file as File)] ??
                  '*/*');
        }
      } else {
        if (_isFileSelected(file)) {
          setState(() => selectedFiles
              .removeWhere((selectedFile) => selectedFile.path == file.path));
          return;
        }
        if (widget.multiSelect == false) {
          selectedFiles.clear();
        }
        setState(() => selectedFiles.add(file as File));
      }
    } catch (e) {
      NotificationService.showSnackbar(
          text: "Something went wrong",
          color: Colors.red,
          showCloseIcon: true);
    }
  }
}

// Folder picker dialog — lets the user browse directories and select a destination.
class _FolderPickerDialog extends StatefulWidget {
  final String startPath;
  const _FolderPickerDialog({required this.startPath});

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  late String _currentPath;
  List<Directory> _dirs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.startPath;
    _loadDirs(_currentPath);
  }

  Future<void> _loadDirs(String path) async {
    setState(() => _loading = true);
    try {
      final dir = Directory(path);
      final entries = await dir.list(followLinks: false).where((e) => e is Directory).cast<Directory>().toList();
      entries.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));
      if (mounted) setState(() { _dirs = entries; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _dirs = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final folderName = _currentPath.split('/').last.isEmpty ? 'Root' : _currentPath.split('/').last;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                if (_currentPath != widget.startPath)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      final parent = Directory(_currentPath).parent.path;
                      setState(() => _currentPath = parent);
                      _loadDirs(parent);
                    },
                  ),
                Expanded(
                  child: Text(
                    folderName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Directory list
          SizedBox(
            height: 300,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _dirs.isEmpty
                    ? Center(
                        child: Text('No sub-folders',
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      )
                    : ListView.builder(
                        itemCount: _dirs.length,
                        itemBuilder: (ctx, i) {
                          final name = _dirs[i].path.split('/').last;
                          return ListTile(
                            leading: Icon(Icons.folder_outlined, color: primary),
                            title: Text(name, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              setState(() => _currentPath = _dirs[i].path);
                              _loadDirs(_dirs[i].path);
                            },
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          // Action row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentPath.replaceFirst(widget.startPath, '…'),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _currentPath),
                  child: const Text('Select'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
