import 'dart:io';
import 'dart:typed_data';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

/// Manages Google Sign-In authentication and Google Drive file operations.
///
/// Setup required:
/// 1. Create a project at https://console.cloud.google.com
/// 2. Enable the Google Drive API
/// 3. Create an OAuth 2.0 Android client ID (use your app's SHA-1 + package name)
/// 4. Download google-services.json and place it in android/app/
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._();
  GoogleDriveService._();
  factory GoogleDriveService() => _instance;

  // driveFileScope: create/upload files; driveReadonlyScope: list all existing files
  final _signIn = GoogleSignIn(scopes: [
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveReadonlyScope,
  ]);

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Signs in silently first (restores previous session), then interactively if needed.
  Future<GoogleSignInAccount?> signIn() async {
    _currentUser = await _signIn.signInSilently();
    _currentUser ??= await _signIn.signIn();
    return _currentUser;
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    _currentUser = null;
  }

  /// Uploads [file] to Google Drive under the folder "PDF Craft" (created if not present).
  /// Returns the uploaded file's Drive ID, or null on failure.
  Future<String?> uploadFile(File file) async {
    _currentUser ??= await _signIn.signInSilently();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');

    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');

    final api = drive.DriveApi(authClient);

    // Find or create "PDF Craft" folder in Drive root
    final folderId = await _ensureFolder(api, 'PDF Craft');

    final fileName = file.path.split('/').last;

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(
      file.openRead(),
      file.lengthSync(),
      contentType: _mimeTypeForFile(fileName),
    );
    final result = await api.files.create(driveFile, uploadMedia: media);

    authClient.close();
    return result.id;
  }

  /// Returns storage quota info: `limit` and `usage` in bytes as strings.
  Future<drive.About> getStorageQuota() async {
    _currentUser ??= await _signIn.signInSilently();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');
    final api = drive.DriveApi(authClient);
    final about = await api.about.get($fields: 'storageQuota');
    authClient.close();
    return about;
  }

  /// Deletes a file from the user's Drive by its file ID.
  Future<void> deleteFile(String fileId) async {
    _currentUser ??= await _signIn.signInSilently();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');
    final api = drive.DriveApi(authClient);
    await api.files.delete(fileId);
    authClient.close();
  }

  /// Downloads a Drive file to the device's temp directory.
  /// [onProgress] is called with values 0.0–1.0 as bytes accumulate.
  Future<File> downloadFile(String fileId, String fileName, {void Function(double)? onProgress}) async {
    _currentUser ??= await _signIn.signInSilently();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');

    final api = drive.DriveApi(authClient);
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    final sink = file.openWrite();

    final chunks = <int>[];
    final total = media.length ?? 0;

    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
      sink.add(chunk);
      if (onProgress != null && total > 0) {
        onProgress(chunks.length / total);
      }
    }
    await sink.flush();
    await sink.close();
    authClient.close();
    return file;
  }

  /// Lists all files in the user's Drive (not trashed), newest first.
  Future<List<drive.File>> listFiles() async {
    _currentUser ??= await _signIn.signInSilently();
    if (_currentUser == null) return [];

    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) return [];

    final api = drive.DriveApi(authClient);
    final result = await api.files.list(
      q: "trashed = false and mimeType != 'application/vnd.google-apps.folder'",
      $fields: 'files(id, name, size, modifiedTime, mimeType)',
      orderBy: 'modifiedTime desc',
      pageSize: 100,
    );

    authClient.close();
    return result.files ?? [];
  }

  /// Ensures the named folder exists in Drive root. Returns its folder ID.
  Future<String> _ensureFolder(drive.DriveApi api, String folderName) async {
    final existing = await api.files.list(
      q: "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      $fields: 'files(id)',
    );
    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  String _mimeTypeForFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }
}
