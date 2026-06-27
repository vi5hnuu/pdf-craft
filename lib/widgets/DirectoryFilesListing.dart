import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/state/selection/SelectionService.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/Debouncer.dart';
import 'package:pdf_craft/utils/FileSortFilter.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/FileTile.dart';
import 'package:pdf_craft/widgets/SelectionBar.dart';
import 'package:pdf_craft/widgets/SortControls.dart';
import 'package:open_file/open_file.dart';

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
  FileSortMode _sortMode = FileSortMode.name;

  // Filtering / sorting controls (item 1).
  bool _ascending = true; // sort direction toggle
  String _nameFilter = ''; // case-insensitive substring filter on file name
  String? _extFilter; // selected file-type extension filter (e.g. '.pdf')
  final _filterDebouncer = Debouncer(milliseconds: 250);
  final _searchController = TextEditingController();

  /// Browse mode = plain file browsing (no tool picker). Only in this mode do
  /// we enable the global cross-folder selection + tool intellisense bar; the
  /// picker flow keeps its own local [selectedFiles] + "Complete Selection".
  bool get _browseMode => widget.multiSelect == null;

  @override
  void initState() {
    bloc = BlocProvider.of<FilesBloc>(context);
    pathToDirectory = [widget.directoryPath];
    _loadDirectoryFiles(pathToDirectory.last);
    if (_browseMode) SelectionService().addListener(_onSelectionChanged);
    super.initState();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  /// Applies the active name/extension filters and sort via the shared utility.
  List<FileSystemEntity> _visibleFiles(List<FileSystemEntity> files) =>
      applySortFilter(files,
          nameQuery: _nameFilter,
          ext: _extFilter,
          mode: _sortMode,
          ascending: _ascending);

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Back first cancels an active cross-folder selection.
        if (_browseMode && SelectionService().isActive) {
          SelectionService().clear();
          return;
        }
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
          // Compute filtered+sorted list once per build — avoids re-sorting for every item in ListView
          final sortedFiles = _visibleFiles(state.files);

          return Stack(children: [
            if (!state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES))
              (state.files.isEmpty
                  ? const Center(child: Text('No files found'))
                  : Flex(
                      direction: Axis.vertical,
                      children: [
                        _buildBreadcrumbAndSort(theme, primary, state.files),
                        Flexible(
                          fit: FlexFit.tight,
                          child: sortedFiles.isEmpty
                              ? Center(
                                  child: Text(
                                    'No matching files',
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5)),
                                  ),
                                )
                              : ListView.builder(
                            itemCount: sortedFiles.length,
                            itemBuilder: (context, index) {
                              final file = sortedFiles[index];

                              if ((file is Directory) &&
                                  widget.excludeShowingDirsPath
                                          ?.contains(file.path) ==
                                      true) {
                                return const SizedBox.shrink();
                              }

                              if (deletedFiles.contains(file)) {
                                // Hide while deletion/move is in progress; bloc will refresh list on success
                                if (state.isLoading(forr: HttpStates.DELETE_FILE) ||
                                    state.isLoading(forr: HttpStates.MOVE_FILE_TO)) {
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
                        // Cross-folder selection bar (browse mode only).
                        if (_browseMode && SelectionService().isActive)
                          const SelectionBar(),
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

  Widget _buildBreadcrumbAndSort(
      ThemeData theme, Color primary, List<FileSystemEntity> allFiles) {
    final availableExts = availableExtensions(allFiles).toList()..sort();
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
          const SizedBox(height: 8),
          // Name filter (debounced so typing doesn't rebuild on every keystroke).
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Filter by name',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _nameFilter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _filterDebouncer.cancel();
                          setState(() => _nameFilter = '');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => _filterDebouncer.run(() {
                if (mounted) setState(() => _nameFilter = v);
              }),
            ),
          ),
          const SizedBox(height: 6),
          // Sort field + direction (shared control) + type filter.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SortControls(
                  mode: _sortMode,
                  ascending: _ascending,
                  onModeChanged: (m) => setState(() => _sortMode = m),
                  onToggleDirection: () =>
                      setState(() => _ascending = !_ascending),
                ),
                if (availableExts.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _pill(theme, primary,
                      label: 'All',
                      selected: _extFilter == null,
                      onTap: () => setState(() => _extFilter = null)),
                  for (final ext in availableExts) ...[
                    const SizedBox(width: 4),
                    _pill(theme, primary,
                        label: ext,
                        selected: _extFilter == ext,
                        onTap: () => setState(() => _extFilter = ext)),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Small selectable pill used for sort-field and type-filter chips.
  Widget _pill(ThemeData theme, Color primary,
      {required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? primary : theme.dividerColor, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected
                ? primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  bool _isFileSelected(FileSystemEntity file) {
    if (file is Directory) return false;
    if (_browseMode) return SelectionService().contains(file.path);
    return selectedFiles.any((selectedFile) => selectedFile.path == file.path);
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
            if (!isDir && _browseMode)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(
                    _isFileSelected(file) ? 'Deselect' : 'Select for tools'),
                onTap: () {
                  Navigator.pop(context);
                  SelectionService().toggle(file as File);
                },
              ),
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
              _infoRow(Icons.insert_drive_file_outlined, 'Name', name, copyable: true),
              const SizedBox(height: 12),
              _infoRow(Icons.folder_outlined, 'Path', file.path, copyable: true),
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

  Widget _infoRow(IconData icon, String label, String value,
      {bool copyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        // Expanded so long values (e.g. paths) wrap instead of overflowing.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              NotificationService.showSnackbar(
                  text: 'Copied to clipboard', color: Colors.green);
            },
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
          maxLines: 1,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'New name',
            suffixText: ext,
            isDense: true,
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
    if (_browseMode) {
      SelectionService().removeListener(_onSelectionChanged);
      // Don't leak a cross-folder selection out of the browser.
      SelectionService().clear();
    }
    _filterDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  _onItemClick({required FileSystemEntity file}) async {
    try {
      if (file is Directory) {
        _loadDirectoryFiles((pathToDirectory..add(file.path)).last);
        return;
      }

      if (widget.multiSelect == null) {
        // Browse mode: while a cross-folder selection is active, a tap toggles
        // selection instead of opening the file.
        if (SelectionService().isActive) {
          SelectionService().toggle(file as File);
          return;
        }
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
