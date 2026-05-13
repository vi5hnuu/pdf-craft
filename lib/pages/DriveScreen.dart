import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:pdf_craft/services/cloud/GoogleDriveService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/utils/utility.dart';

/// Google Drive integration screen.
/// Shows sign-in, uploaded file list, and allows uploading local files.
class DriveScreen extends StatefulWidget {
  final File? fileToUpload; // when opened from "Upload to Drive" action
  const DriveScreen({super.key, this.fileToUpload});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  final _drive = GoogleDriveService();
  bool _signingIn = false;
  bool _loadingFiles = false;
  bool _uploading = false;
  List<drive.File> _files = [];

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    setState(() => _signingIn = true);
    try {
      await _drive.signIn(); // tries silent sign-in first
      if (_drive.isSignedIn) await _loadFiles();
    } catch (_) {
      // Silent sign-in may fail if not previously signed in — that's OK
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await _drive.signIn();
      if (_drive.isSignedIn) await _loadFiles();
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Sign-in failed', color: Colors.red);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    setState(() => _files = []);
  }

  Future<void> _loadFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final files = await _drive.listFiles();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Failed to load Drive files', color: Colors.red);
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _uploadFile(File file) async {
    setState(() => _uploading = true);
    try {
      await _drive.uploadFile(file);
      NotificationService.showSnackbar(text: 'Uploaded to Google Drive', color: Colors.green);
      await _loadFiles();
    } catch (e) {
      if (mounted) NotificationService.showSnackbar(text: 'Upload failed: ${e.toString()}', color: Colors.red);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive'),
        actions: [
          if (_drive.isSignedIn) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadingFiles ? null : _loadFiles,
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
      body: _signingIn
          ? const Center(child: CircularProgressIndicator())
          : !_drive.isSignedIn
              ? _buildSignInPrompt(theme)
              : _buildFileList(theme, primary),
      floatingActionButton: _drive.isSignedIn && widget.fileToUpload != null
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : () => _uploadFile(widget.fileToUpload!),
              icon: _uploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
              label: Text(_uploading ? 'Uploading…' : 'Upload ${widget.fileToUpload!.path.split('/').last}'),
            )
          : null,
    );
  }

  Widget _buildSignInPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 72, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Connect Google Drive', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Sign in to upload your processed files directly to Google Drive.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              onPressed: _signIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(ThemeData theme, Color primary) {
    if (_loadingFiles) return const Center(child: CircularProgressIndicator());

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('No files uploaded yet'),
            if (widget.fileToUpload != null) ...[
              const SizedBox(height: 8),
              Text('Tap the button below to upload your file.', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final f = _files[i];
          final name = f.name ?? 'Unknown';
          final size = f.size != null ? Utility.bytesToSize(int.tryParse(f.size!) ?? 0) : '';
          final modified = f.modifiedTime != null
              ? '${f.modifiedTime!.day}/${f.modifiedTime!.month}/${f.modifiedTime!.year}'
              : '';
          return ListTile(
            leading: Icon(_iconFor(name), color: primary),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('$size  $modified'.trim(), style: const TextStyle(fontSize: 12)),
          );
        },
      ),
    );
  }

  IconData _iconFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'docx' || 'doc' => Icons.description_outlined,
      'xlsx' || 'xls' => Icons.table_chart_outlined,
      'pptx' || 'ppt' => Icons.slideshow_outlined,
      'jpg' || 'jpeg' || 'png' => Icons.image_outlined,
      'txt' => Icons.text_snippet_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}
