import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/cloud/GoogleDriveService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:go_router/go_router.dart';

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

  drive.About? _storageAbout;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
    if (widget.fileToUpload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoUpload());
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
      await _drive.signIn();
      if (_drive.isSignedIn) await Future.wait([_loadFiles(), _loadStorage()]);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await _drive.signIn();
      if (_drive.isSignedIn) await Future.wait([_loadFiles(), _loadStorage()]);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Sign-in failed', color: Colors.red);
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
      final files = await _drive.listFiles();
      if (mounted) setState(() => _allFiles = files);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Failed to load Drive files', color: Colors.red);
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
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
      if (mounted) NotificationService.showSnackbar(text: 'Uploaded to Google Drive', color: Colors.green);
      await Future.wait([_loadFiles(), _loadStorage()]);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Upload failed: $e', color: Colors.red);
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
      if (mounted) NotificationService.showSnackbar(text: 'Downloaded to processed folder', color: Colors.green);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Download failed: $e', color: Colors.red);
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
      if (mounted) NotificationService.showSnackbar(text: 'Could not open: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _deleteFile(drive.File f) async {
    if (f.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file'),
        content: Text('Delete "${f.name}" from Google Drive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _drive.deleteFile(f.id!);
      await Future.wait([_loadFiles(), _loadStorage()]);
      if (mounted) NotificationService.showSnackbar(text: 'Deleted from Drive', color: Colors.orange);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Delete failed: $e', color: Colors.red);
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
        title: const Text('Google Drive'),
        actions: [
          if (_drive.isSignedIn) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadingFiles ? null : () => Future.wait([_loadFiles(), _loadStorage()]),
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: 'Sign Out',
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
              label: Text(_uploading ? 'Uploading…' : 'Upload File'),
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
          Text('Connect Google Drive', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Sign in to upload, download and manage your Drive files.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Sign in with Google'),
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
                Text(user?.displayName ?? 'Google Drive',
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
              '${Utility.bytesToSize(used)} of ${Utility.bytesToSize(limit)} used',
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

  String _filterLabel(_FileFilter f) => switch (f) {
    _FileFilter.all => 'All',
    _FileFilter.pdf => 'PDFs',
    _FileFilter.images => 'Images',
    _FileFilter.docs => 'Documents',
    _FileFilter.other => 'Other',
  };

  Widget _buildFileList(ThemeData theme) {
    final files = _filteredFiles;
    if (files.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_open_outlined, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(_filter == _FileFilter.all ? 'No files in your Drive' : 'No ${_filterLabel(_filter)} found'),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => Future.wait([_loadFiles(), _loadStorage()]),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        itemCount: files.length,
        itemBuilder: (context, i) => _buildFileCard(theme, files[i]),
      ),
    );
  }

  Widget _buildFileCard(ThemeData theme, drive.File f) {
    final name = f.name ?? 'Unknown';
    final size = f.size != null ? Utility.bytesToSize(int.tryParse(f.size!) ?? 0) : '';
    final modified = f.modifiedTime != null
        ? '${f.modifiedTime!.day}/${f.modifiedTime!.month}/${f.modifiedTime!.year}'
        : '';
    final isPdf = (f.mimeType ?? '') == 'application/pdf';
    final isDownloading = _downloadingId == f.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (isPdf)
              TextButton.icon(
                onPressed: isDownloading ? null : () => _openPdf(f),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
              ),
            TextButton.icon(
              onPressed: isDownloading ? null : () => _downloadFile(f),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Download'),
            ),
            TextButton.icon(
              onPressed: isDownloading ? null : () => _deleteFile(f),
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ]),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: bg == Colors.grey.shade200 ? Colors.grey : null),
    );
  }
}
