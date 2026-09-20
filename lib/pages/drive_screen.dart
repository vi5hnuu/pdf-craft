import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/cloud/google_drive_service.dart';
import 'package:pdf_craft/singletons/full_screen_ad_policy.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/widgets/text_prompt.dart';
import 'package:pdf_craft/widgets/tool_picker_sheet.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/singletons/file_store.dart';
import 'package:pdf_craft/utils/debouncer.dart';
import 'package:pdf_craft/utils/upload_limits.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_craft/theme/app_radius.dart';

enum _FileFilter { all, pdf, images, docs, other }

/// Comprehensive Google Drive screen: account info, storage, file list
/// with filter chips, per-file actions (open, download, delete), and upload FAB.
class DriveScreen extends StatefulWidget {
  final File? fileToUpload;
  const DriveScreen({super.key, this.fileToUpload});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  final _drive = GoogleDriveService();
  bool _signingIn = false;
  bool _loadingFiles = false;
  bool _uploading = false;

  List<drive.File> _allFiles = [];
  _FileFilter _filter = _FileFilter.all;
  String? _downloadingId;

  // Pagination over the Drive file list.
  String? _nextPageToken;

  /// Folder breadcrumb, root-first. Empty means the flat "recent files" view, which is what the
  /// screen could *only* ever show before — folders were excluded by the listing query.
  final List<({String id, String name})> _path = [];

  /// Server-side name search. The old filter chips could only match files already paged in.
  String _search = '';
  final _searchController = TextEditingController();
  final _searchDebouncer = Debouncer(milliseconds: 400);

  /// 0..1 while a file is downloading. The service has always accepted an onProgress callback
  /// and nothing passed one, so the bar was indeterminate however large the file was.
  double? _downloadProgress;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  drive.About? _storageAbout;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tryRestoreSession();
    if (widget.fileToUpload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoUpload());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    // Debounced because each keystroke is a Drive API round-trip, not a filter over a local list.
    _searchDebouncer.run(() {
      if (!mounted || v.trim() == _search) return;
      setState(() {
        _search = v.trim();
        _allFiles = [];
        _nextPageToken = null;
      });
      _loadFiles();
    });
  }

  void _onScroll() {
    // Load the next page as the user approaches the bottom.
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _autoUpload() async {
    if (widget.fileToUpload != null && _drive.isSignedIn) {
      await _uploadFile(widget.fileToUpload!);
    }
  }

  Future<void> _tryRestoreSession() async {
    setState(() => _signingIn = true);
    try {
      // Silent only: opening the Cloud tab used to launch the Google account picker on its own.
      // Users who never connected Drive now just see the "Connect Google Drive" prompt.
      await _drive.restoreSession();
      if (_drive.isSignedIn) await Future.wait([_loadFiles(), _loadStorage()]);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      // Interactive sign-in opens the account picker; its return must not trigger an ad.
      await FullScreenAdPolicy().runExternal(() => _drive.signIn());
      if (_drive.isSignedIn) await Future.wait([_loadFiles(), _loadStorage()]);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveSignInFailed, color: Colors.red);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    if (mounted) setState(() { _allFiles = []; _storageAbout = null; });
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => _loadingFiles = true);
    try {
      final page = await _drive.listFiles(
          folderId: _path.isEmpty ? null : _path.last.id, query: _search);
      if (mounted) {
        setState(() {
          _allFiles = page.files;
          _nextPageToken = page.nextPageToken;
        });
      }
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveLoadFailed, color: Colors.red);
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  /// Opens a folder, or goes back up to [depth] entries.
  void _openFolder(drive.File folder) {
    if (folder.id == null) return;
    _searchController.clear();
    setState(() {
      _path.add((id: folder.id!, name: folder.name ?? '—'));
      // A search is what surfaced this folder; carrying it inside would show an almost-empty
      // folder for no visible reason.
      _search = '';
      _allFiles = [];
      _nextPageToken = null;
    });
    _loadFiles();
  }

  void _popTo(int depth) {
    _searchController.clear();
    setState(() {
      _path.removeRange(depth, _path.length);
      _search = '';
      _allFiles = [];
      _nextPageToken = null;
    });
    _loadFiles();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextPageToken == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _drive.listFiles(
          pageToken: _nextPageToken,
          folderId: _path.isEmpty ? null : _path.last.id,
          query: _search);
      if (mounted) {
        setState(() {
          _allFiles = [..._allFiles, ...page.files];
          _nextPageToken = page.nextPageToken;
        });
      }
    } catch (_) {
      // Silent — the already-loaded files remain usable.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadStorage() async {
    try {
      final about = await _drive.getStorageQuota();
      if (mounted) setState(() => _storageAbout = about);
    } catch (_) {}
  }

  Future<void> _uploadFile(File file) async {
    setState(() => _uploading = true);
    try {
      // Uploads land where the user is looking. They always went to the app's own folder before,
      // even when browsing somewhere else entirely.
      await _drive.uploadFile(file, parentId: _path.isEmpty ? null : _path.last.id);
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveUploaded, color: Colors.green);
      await Future.wait([_loadFiles(), _loadStorage()]);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveUploadFailed('$e'), color: Colors.red);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    await _uploadFile(File(result.files.single.path!));
  }

  Future<void> _downloadFile(drive.File f) async {
    if (f.id == null || f.name == null) return;
    setState(() => _downloadingId = f.id);
    try {
      final dir = Directory(Constants.processedDirPath);
      if (!dir.existsSync()) await dir.create(recursive: true);
      final tmpFile = await _fetch(f);
      final dest = File('${Constants.processedDirPath}/${tmpFile.path.split('/').last}');
      await tmpFile.copy(dest.path);
      FileStore().changed();
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveDownloaded, color: Colors.green);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveDownloadFailed('$e'), color: Colors.red);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _openPdf(drive.File f) async {
    if (f.id == null || f.name == null) return;
    try {
      final tmpFile = await _fetch(f);
      if (!mounted) return;
      GoRouter.of(context).pushNamed(
        AppRoutes.pdfFilePreviewRoute.name,
        pathParameters: {'pdfFilePath': tmpFile.path},
      );
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveCouldNotOpen('$e'), color: Colors.red);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  /// Downloads the Drive file, then offers the PDF/image tools that apply to it
  /// (intellisense via [ToolRegistry]). This makes the cloud tab tool-oriented
  /// rather than a generic file manager.
  Future<void> _useInTools(drive.File f) async {
    if (f.id == null || f.name == null) return;
    // Refuse an oversize file *before* spending the download. The tool would have checked it
    // anyway — but only after the bytes had already come down the wire.
    final declared = int.tryParse(f.size ?? '') ?? 0;
    if (declared > 0) {
      final violation = UploadLimits.evaluate([MapEntry(f.name!, declared)]);
      if (violation != null) {
        await UploadLimits.explain(context, violation);
        return;
      }
    }
    final File local;
    try {
      local = await _fetch(f);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveCouldNotFetch('$e'), color: Colors.red);
      return;
    }
    if (!mounted) return;

    final tools = ToolRegistry.toolsForSelection([local]);
    if (tools.isEmpty) {
      NotificationService.showSnackbar(text: L10n.current.driveNoToolsForType, color: Colors.orange);
      return;
    }
    ToolPickerSheet.show(
      context,
      files: [local],
      subtitle: local.path.split('/').last,
      onSelected: (tool) => unawaited(tool.openWithFiles(context, [local])),
    );
  }

  /// Downloads [f] once and keeps it, reporting real progress.
  ///
  /// Every caller used to re-download: opening a PDF, then sharing it, then sending it to a tool
  /// fetched the same bytes three times. The cache is keyed on the Drive id *and* the modified
  /// time, so an edit made in Drive is still picked up.
  final Map<String, File> _fetched = {};

  Future<File> _fetch(drive.File f) async {
    final key = '${f.id}@${f.modifiedTime?.toIso8601String() ?? ''}';
    final cached = _fetched[key];
    if (cached != null && cached.existsSync()) return cached;

    setState(() {
      _downloadingId = f.id;
      _downloadProgress = null; // indeterminate until the first chunk reports a fraction
    });
    try {
      final local = await _drive.downloadFile(
        f.id!,
        f.name!,
        exportMime: GoogleDriveService.exportMimeFor(f),
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      _fetched[key] = local;
      return local;
    } finally {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _downloadProgress = null;
        });
      }
    }
  }

  /// Renames a Drive file or folder in place.
  ///
  /// `renameFile` and `deleteFile` both existed in the service with zero call sites, so the
  /// screen advertised itself as Drive management while offering neither.
  Future<void> _rename(drive.File f) async {
    if (f.id == null) return;
    final newName = await promptForText(
      context,
      title: GoogleDriveService.isFolder(f)
          ? L10n.of(context).renameFolder
          : L10n.of(context).renameFile,
      initial: f.name ?? '',
      confirmLabel: L10n.of(context).rename,
    );
    if (newName == null || newName.isEmpty || newName == f.name) return;
    try {
      await _drive.renameFile(f.id!, newName);
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.renamedSuccessfully, color: Colors.green);
      }
      await _loadFiles();
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.renameFailed, color: Colors.red);
      }
    }
  }

  /// Moves a Drive item to the trash, after confirming. Trash rather than permanent delete —
  /// see [GoogleDriveService.deleteFile].
  Future<void> _delete(drive.File f) async {
    if (f.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).delete),
        content: Text(L10n.of(ctx).confirmDeleteFile(f.name ?? '')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.of(ctx).cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(ctx).delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _drive.deleteFile(f.id!);
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.driveDeleted, color: Colors.green);
      }
      await Future.wait([_loadFiles(), _loadStorage()]);
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.driveDeleteFailed('$e'), color: Colors.red);
      }
    }
  }

  /// Creates a folder in the folder currently being browsed.
  Future<void> _createFolder() async {
    final name = await promptForText(
      context,
      title: L10n.of(context).driveNewFolder,
      label: L10n.of(context).driveFolderName,
      confirmLabel: L10n.of(context).create,
    );
    if (name == null || name.isEmpty) return;
    try {
      await _drive.createFolder(name,
          parentId: _path.isEmpty ? null : _path.last.id);
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.driveFolderCreated, color: Colors.green);
      }
      await _loadFiles();
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackbar(
            text: L10n.current.driveUploadFailed('$e'), color: Colors.red);
      }
    }
  }

  /// Downloads the Drive file and opens the system share sheet.
  Future<void> _shareFile(drive.File f) async {
    if (f.id == null || f.name == null) return;
    try {
      final local = await _fetch(f);
      if (!mounted) return;
      await Share.shareXFiles([XFile(local.path)]);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveShareFailed('$e'), color: Colors.red);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  List<drive.File> get _filteredFiles {
    return _allFiles.where((f) {
      final mime = f.mimeType ?? '';
      return switch (_filter) {
        _FileFilter.all => true,
        _FileFilter.pdf => mime == 'application/pdf',
        _FileFilter.images => mime.startsWith('image/'),
        _FileFilter.docs => mime.contains('word') || mime.contains('excel') || mime.contains('presentation') || mime.contains('spreadsheet') || mime.contains('powerpoint'),
        _FileFilter.other => mime != 'application/pdf' && !mime.startsWith('image/') && !mime.contains('word') && !mime.contains('excel') && !mime.contains('presentation') && !mime.contains('spreadsheet') && !mime.contains('powerpoint'),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).googleDrive),
        actions: [
          if (_drive.isSignedIn) ...[
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _createFolder,
              tooltip: L10n.of(context).driveNewFolder,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadingFiles ? null : () => Future.wait([_loadFiles(), _loadStorage()]),
              tooltip: L10n.of(context).refresh,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: L10n.of(context).signOut,
            ),
          ],
        ],
      ),
      floatingActionButton: _drive.isSignedIn
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
              label: Text(_uploading ? L10n.of(context).driveUploading : L10n.of(context).driveUploadFile),
            )
          : null,
      body: _signingIn
          ? const Center(child: CircularProgressIndicator())
          : !_drive.isSignedIn
              ? _buildSignInPrompt(theme)
              : _buildSignedIn(theme),
    );
  }

  Widget _buildSignInPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_outlined, size: 72, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(L10n.of(context).driveConnect, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            L10n.of(context).driveConnectBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: Text(L10n.of(context).driveSignInWithGoogle),
            onPressed: _signIn,
          ),
        ]),
      ),
    );
  }

  Widget _buildSignedIn(ThemeData theme) {
    return Column(children: [
      _buildAccountHeader(theme),
      _buildSearchField(theme),
      _buildBreadcrumb(theme),
      _buildFilterChips(theme),
      Expanded(child: _loadingFiles
          ? const Center(child: CircularProgressIndicator())
          : _buildFileList(theme)),
    ]);
  }

  /// Server-side name search. The filter chips below it only ever narrowed the page already in
  /// memory, so a file further down a large Drive was unreachable from this screen.
  Widget _buildSearchField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          isDense: true,
          hintText: L10n.of(context).driveSearchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
          // Trimmed, like the query itself: a field holding only spaces searches for nothing,
          // so offering a Clear button for it points at a state the user cannot see.
          suffixIcon: _search.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: L10n.of(context).clear,
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.surface)),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  /// Root-first path, so a folder several levels down can be left without walking back one tap
  /// at a time.
  Widget _buildBreadcrumb(ThemeData theme) {
    if (_path.isEmpty && _search.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          TextButton.icon(
            onPressed: _path.isEmpty ? null : () => _popTo(0),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: Text(L10n.of(context).driveMyDrive),
          ),
          for (var i = 0; i < _path.length; i++) ...[
            const Icon(Icons.chevron_right, size: 16),
            TextButton(
              // The last crumb is where we already are.
              onPressed: i == _path.length - 1 ? null : () => _popTo(i + 1),
              child: Text(_path[i].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildAccountHeader(ThemeData theme) {
    final user = _drive.currentUser;
    final quota = _storageAbout?.storageQuota;
    final used = int.tryParse(quota?.usage ?? '') ?? 0;
    final limit = int.tryParse(quota?.limit ?? '') ?? 0;
    final progress = limit > 0 ? used / limit : 0.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
              child: user?.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.displayName ?? L10n.of(context).googleDrive,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(user?.email ?? '', style: theme.textTheme.bodySmall),
              ]),
            ),
          ]),
          if (limit > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 4),
            Text(
              L10n.of(context).driveStorageUsed(Utility.bytesToSize(used), Utility.bytesToSize(limit)),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: _FileFilter.values.map((f) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(_filterLabel(f)),
          selected: _filter == f,
          onSelected: (_) => setState(() => _filter = f),
        ),
      )).toList()),
    );
  }

  String _filterLabel(_FileFilter f) {
    final l = L10n.of(context);
    return switch (f) {
      _FileFilter.all => l.filterAll,
      _FileFilter.pdf => l.filterPdfs,
      _FileFilter.images => l.filterImages,
      _FileFilter.docs => l.filterDocuments,
      _FileFilter.other => l.filterOther,
    };
  }

  Widget _buildFileList(ThemeData theme) {
    final files = _filteredFiles;
    if (files.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_open_outlined, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(_emptyMessage()),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => Future.wait([_loadFiles(), _loadStorage()]),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        // +1 for the trailing paging indicator when more pages exist.
        itemCount: files.length + (_nextPageToken != null ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= files.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final f = files[i];
          // Folders are rows you can walk into, not file cards. They were excluded from the
          // listing entirely until now, which is why this screen was one flat list.
          if (GoogleDriveService.isFolder(f)) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.folder, color: theme.colorScheme.primary),
                title: Text(f.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: _itemMenu(f),
                onTap: () => _openFolder(f),
              ),
            );
          }
          return _buildFileCard(theme, f);
        },
      ),
    );
  }

  /// The empty list means different things depending on where you are: a search with no hits, a
  /// folder you have walked into, or a Drive with nothing of that type. It used to say "No files
  /// in your Drive" in all three cases.
  String _emptyMessage() {
    final l = L10n.of(context);
    if (_search.isNotEmpty) return l.driveNoResults(_search);
    if (_filter != _FileFilter.all) return l.driveNoFilesOfType(_filterLabel(_filter));
    if (_path.isNotEmpty) return l.driveEmptyFolder;
    return l.driveNoFiles;
  }

  /// Rename/delete, shared by folder rows and file cards.
  Widget _itemMenu(drive.File f) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (v) => v == 'rename' ? _rename(f) : _delete(f),
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(L10n.of(ctx).rename)),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(L10n.of(ctx).delete)),
          ),
        ],
      );

  Widget _buildFileCard(ThemeData theme, drive.File f) {
    final name = f.name ?? L10n.of(context).unknown;
    final size = f.size != null ? Utility.bytesToSize(int.tryParse(f.size!) ?? 0) : '';
    final modified = f.modifiedTime != null
        ? '${f.modifiedTime!.day}/${f.modifiedTime!.month}/${f.modifiedTime!.year}'
        : '';
    final exportMime = GoogleDriveService.exportMimeFor(f);
    // Google-native files open as their exported form; everything else keeps its own type.
    final exportsAs = exportMime == 'application/pdf' ? 'PDF' : null;
    final isPdf = (f.mimeType ?? '') == 'application/pdf' || exportMime == 'application/pdf';
    final isDownloading = _downloadingId == f.id;
    // Determinate when the server told us the size. The service has always offered onProgress
    // and nothing passed one, so this was a barber's pole however big the file was.
    final downloadProgress = isDownloading ? _downloadProgress : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12,10,12,0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _thumbnail(f, name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('$size  $modified'.trim(), style: theme.textTheme.bodySmall),
                // A Doc or a Sheet has no bytes to fetch, so it comes down as a PDF export.
                // Say so before the download rather than letting the file name surprise them.
                if (exportsAs != null)
                  Text(L10n.of(context).driveExportsAs(exportsAs),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary)),
              ]),
            ),
            _itemMenu(f),
          ]),
          if (isDownloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: downloadProgress),
          ],
          const SizedBox(height: 8),
          // Tool-oriented actions. Rename and Delete live in the overflow menu above, so the
          // common path stays one row of verbs and the destructive one is not adjacent to it.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              if (isPdf)
                TextButton.icon(
                  onPressed: isDownloading ? null : () => _openPdf(f),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(L10n.of(context).actionOpen),
                ),
              TextButton.icon(
                onPressed: isDownloading ? null : () => _useInTools(f),
                icon: const Icon(Icons.build_outlined, size: 18),
                label: Text(L10n.of(context).navTools),
              ),
              TextButton.icon(
                onPressed: isDownloading ? null : () => _downloadFile(f),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(L10n.of(context).actionSave),
              ),
              TextButton.icon(
                onPressed: isDownloading ? null : () => _shareFile(f),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(L10n.of(context).actionShare),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  /// The file's Drive thumbnail, falling back to the typed icon box.
  ///
  /// `thumbnailLink` was not in the field mask at all, so every card — including a scan or a
  /// photo — showed the same generic MIME glyph. The link is short-lived and can 404, hence the
  /// errorBuilder rather than a bare Image.network.
  Widget _thumbnail(drive.File f, String name) {
    final link = f.thumbnailLink;
    if (link == null || link.isEmpty) return _fileIconBox(name, f.mimeType);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.surface),
      child: Image.network(
        link,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fileIconBox(name, f.mimeType),
      ),
    );
  }

  Widget _fileIconBox(String name, String? mimeType) {
    final mime = mimeType ?? '';
    final Color bg;
    final IconData icon;
    if (mime == 'application/pdf') {
      bg = Colors.red.shade100; icon = Icons.picture_as_pdf_outlined;
    } else if (mime.startsWith('image/')) {
      bg = Colors.teal.shade100; icon = Icons.image_outlined;
    } else if (mime.contains('word')) {
      bg = Colors.blue.shade100; icon = Icons.description_outlined;
    } else if (mime.contains('excel') || mime.contains('spreadsheet')) {
      bg = Colors.green.shade100; icon = Icons.table_chart_outlined;
    } else if (mime.contains('presentation') || mime.contains('powerpoint')) {
      bg = Colors.orange.shade100; icon = Icons.slideshow_outlined;
    } else {
      bg = Colors.grey.shade200; icon = Icons.insert_drive_file_outlined;
    }
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.surface)),
      child: Icon(icon, color: bg == Colors.grey.shade200 ? Colors.grey : null),
    );
  }
}
