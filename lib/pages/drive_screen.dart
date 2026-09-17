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
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/singletons/file_store.dart';
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
    super.dispose();
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
      final page = await _drive.listFiles();
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

  Future<void> _loadMore() async {
    if (_loadingMore || _nextPageToken == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _drive.listFiles(pageToken: _nextPageToken);
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
      await _drive.uploadFile(file);
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
      final tmpFile = await _drive.downloadFile(f.id!, f.name!);
      final dest = File('${Constants.processedDirPath}/${f.name}');
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
    setState(() => _downloadingId = f.id);
    try {
      final tmpFile = await _drive.downloadFile(f.id!, f.name!);
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
    setState(() => _downloadingId = f.id);
    File local;
    try {
      local = await _drive.downloadFile(f.id!, f.name!);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: L10n.current.driveCouldNotFetch('$e'), color: Colors.red);
      return;
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
    if (!mounted) return;

    final tools = ToolRegistry.toolsForSelection([local]);
    if (tools.isEmpty) {
      NotificationService.showSnackbar(text: L10n.current.driveNoToolsForType, color: Colors.orange);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.surface))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(L10n.of(context).applyATool,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: tools
                    .map((tool) => ListTile(
                          leading: Icon(tool.icon, color: tool.category.color),
                          title: Text(tool.localizedName(context)),
                          onTap: () {
                            Navigator.pop(context);
                            tool.openWithFiles(context, [local]);
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Downloads the Drive file and opens the system share sheet.
  Future<void> _shareFile(drive.File f) async {
    if (f.id == null || f.name == null) return;
    setState(() => _downloadingId = f.id);
    try {
      final local = await _drive.downloadFile(f.id!, f.name!);
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
      _buildFilterChips(theme),
      Expanded(child: _loadingFiles
          ? const Center(child: CircularProgressIndicator())
          : _buildFileList(theme)),
    ]);
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
          Text(_filter == _FileFilter.all
              ? L10n.of(context).driveNoFiles
              : L10n.of(context).driveNoFilesOfType(_filterLabel(_filter))),
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
          return _buildFileCard(theme, files[i]);
        },
      ),
    );
  }

  Widget _buildFileCard(ThemeData theme, drive.File f) {
    final name = f.name ?? L10n.of(context).unknown;
    final size = f.size != null ? Utility.bytesToSize(int.tryParse(f.size!) ?? 0) : '';
    final modified = f.modifiedTime != null
        ? '${f.modifiedTime!.day}/${f.modifiedTime!.month}/${f.modifiedTime!.year}'
        : '';
    final isPdf = (f.mimeType ?? '') == 'application/pdf';
    final isDownloading = _downloadingId == f.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12,10,12,0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _fileIconBox(name, f.mimeType),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('$size  $modified'.trim(), style: theme.textTheme.bodySmall),
              ]),
            ),
          ]),
          if (isDownloading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 8),
          // Tool-oriented actions (no Delete — this is a PDF toolbox, not a
          // Drive file manager).
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
