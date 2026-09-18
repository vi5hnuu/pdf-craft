import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pdf_craft/singletons/google_account.dart';
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

  // driveFileScope: create/upload files; driveReadonlyScope: list all existing files.
  //
  // Requested incrementally rather than baked into a second GoogleSignIn instance. There is
  // only one Google session per app — the Android plugin keeps a single client and reconfigures
  // it on each `init` — so a second instance did not add a session, it silently redefined the
  // shared one. With Drive's instance constructed last, sign-in lost its serverClientId and
  // the ID token came back null; the other way round, Drive lost its scopes.
  static const _driveScopes = [
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveReadonlyScope,
  ];

  GoogleSignIn get _signIn => GoogleAccount().client;

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Restores a previous session **silently** — never shows the account picker. Use this when a
  /// screen merely opens (e.g. the Cloud tab); only an explicit user tap should call [signIn].
  Future<GoogleSignInAccount?> restoreSession() async {
    // Only counts as a restored Drive session if the scopes are already granted; otherwise the
    // Cloud tab would show itself as connected and then fail on the first request.
    final account = await GoogleAccount().restore();
    _currentUser =
        account != null && await _signIn.canAccessScopes(_driveScopes) ? account : null;
    return _currentUser;
  }

  /// Signs in silently first (restores previous session), then interactively if needed, and
  /// asks for the Drive scopes. Interactive — call only when the user asked to connect Drive.
  Future<GoogleSignInAccount?> signIn() async {
    final account = await GoogleAccount().signIn();
    if (account == null) return _currentUser = null;
    // Consent for Drive is asked for here, at the point the user opened Cloud — not bundled
    // into logging in, where a Drive permission prompt is a good way to lose someone.
    if (!await GoogleAccount().ensureScopes(_driveScopes)) return _currentUser = null;
    return _currentUser = account;
  }

  /// Signs the app out of Google. App-wide: it ends the account session, not just Drive's use
  /// of it, so the caller should expect to be signed out everywhere Google is used.
  Future<void> signOut() async {
    await GoogleAccount().signOut();
    _currentUser = null;
  }

  /// Drops the cached account without touching the Google session — for when something else
  /// has already ended it and this service would otherwise keep reporting itself as connected.
  Future<void> forgetSession() async {
    _currentUser = null;
  }

  /// Uploads [file] to Google Drive under the folder "PDF Craft" (created if not present).
  /// Returns the uploaded file's Drive ID, or null on failure.
  /// Uploads [file]. With [parentId] it lands in that folder; without one it goes to the app's
  /// own "PDF Craft" folder, which is where every upload used to go with no way to choose.
  Future<String?> uploadFile(File file, {String? parentId}) async {
    _currentUser ??= await GoogleAccount().restore();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');

    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');

    final api = drive.DriveApi(authClient);

    final folderId = parentId ?? await _ensureFolder(api, 'PDF Craft');

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
    _currentUser ??= await GoogleAccount().restore();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');
    final api = drive.DriveApi(authClient);
    final about = await api.about.get($fields: 'storageQuota');
    authClient.close();
    return about;
  }

  /// Moves a Drive file to the trash.
  ///
  /// Deliberately a trash, not `files.delete`: `delete` is irreversible and this app is not the
  /// owner of the user's Drive. Trashed files are restorable from Drive itself for 30 days, which
  /// is what someone tapping Delete in a PDF toolbox expects. (This method had no call sites at
  /// all before now, so nothing depended on the destructive behaviour.)
  Future<void> deleteFile(String fileId) async {
    _currentUser ??= await GoogleAccount().restore();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');
    try {
      await drive.DriveApi(authClient)
          .files
          .update(drive.File()..trashed = true, fileId);
    } finally {
      authClient.close();
    }
  }

  /// Downloads a Drive file to the device's temp directory.
  /// [onProgress] is called with values 0.0–1.0 as bytes accumulate.
  Future<File> downloadFile(String fileId, String fileName,
      {void Function(double)? onProgress, String? exportMime}) async {
    _currentUser ??= await GoogleAccount().restore();
    if (_currentUser == null) throw Exception('Not signed in to Google Drive');
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');

    final api = drive.DriveApi(authClient);

    // Google-native documents have no binary content, so `fullMedia` 403s on them. They are
    // exported instead — previously they were listed (and surfaced by the "docs" filter) while
    // every attempt to open one failed with an unexplained error.
    final drive.Media media;
    var name = fileName;
    if (exportMime != null) {
      media = await api.files.export(fileId, exportMime,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      if (exportMime == 'application/pdf' && !name.toLowerCase().endsWith('.pdf')) {
        name = '$name.pdf';
      }
    } else {
      media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    final sink = file.openWrite();

    // Bytes are counted, not accumulated. The old version kept every chunk in a `chunks` list
    // purely to compute progress while *also* streaming to the sink, so a large PDF was held
    // twice in memory for no benefit.
    var received = 0;
    final total = media.length ?? 0;

    try {
      await for (final chunk in media.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null && total > 0) onProgress(received / total);
      }
      await sink.flush();
    } finally {
      await sink.close();
      authClient.close();
    }
    return file;
  }

  /// Renames a Drive file. There was no rename anywhere, despite files.update being available.
  Future<void> renameFile(String fileId, String newName) async {
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');
    try {
      await drive.DriveApi(authClient)
          .files
          .update(drive.File()..name = newName, fileId);
    } finally {
      authClient.close();
    }
  }

  /// Lists a page of the user's Drive.
  ///
  /// [folderId] scopes the listing to one folder ('root' for the top level); null lists
  /// everything, newest first, which is the "all files" view. [query] is a name search, run
  /// server-side rather than by filtering the current page — the old client-side chips could
  /// only ever match what had already been paged in.
  ///
  /// Folders are included when a [folderId] is given, so the listing can be browsed. They used
  /// to be excluded unconditionally by the query, which is why the screen was a single flat
  /// list with no way into a folder.
  Future<({List<drive.File> files, String? nextPageToken})> listFiles({
    String? pageToken,
    String? folderId,
    String? query,
  }) async {
    _currentUser ??= await GoogleAccount().restore();
    if (_currentUser == null) return (files: <drive.File>[], nextPageToken: null);

    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) return (files: <drive.File>[], nextPageToken: null);

    final searching = query != null && query.trim().isNotEmpty;
    final clauses = <String>['trashed = false'];
    if (folderId != null) {
      clauses.add("'${_escape(folderId)}' in parents");
    } else if (!searching) {
      // The flat "recent" view stays file-only: folders have no modified-time ordering that
      // means anything to the user there. A *search*, though, should be able to turn up a
      // folder by name.
      clauses.add("mimeType != 'application/vnd.google-apps.folder'");
    }
    if (searching) {
      clauses.add("name contains '${_escape(query.trim())}'");
    }

    final api = drive.DriveApi(authClient);
    final result = await api.files.list(
      q: clauses.join(' and '),
      // thumbnailLink was not requested at all, which is why every card fell back to a generic
      // MIME icon. iconLink is Drive's own per-type icon and a good fallback.
      $fields: 'nextPageToken, files(id, name, size, modifiedTime, mimeType, '
          'thumbnailLink, iconLink, starred)',
      // Folders first inside a folder, so browsing reads like a file manager.
      orderBy: folderId == null ? 'modifiedTime desc' : 'folder,name',
      pageSize: 50,
      pageToken: pageToken,
    );

    authClient.close();
    return (files: result.files ?? <drive.File>[], nextPageToken: result.nextPageToken);
  }

  /// Escapes a value for a Drive `q` string literal.
  ///
  /// Drive's query language delimits literals with single quotes and escapes them with a
  /// backslash. Without this a folder or a search for `John's` produces a malformed query and
  /// the call fails with a 400 — which the screen would have reported as "failed to load".
  static String _escape(String v) =>
      v.replaceAll('\\', r'\\').replaceAll("'", "\\'");

  /// True when [f] is a Drive folder.
  static bool isFolder(drive.File f) =>
      f.mimeType == 'application/vnd.google-apps.folder';

  /// True when [f] is a Google-native document, which cannot be downloaded with `fullMedia`.
  ///
  /// These were listed — and actively surfaced by the "docs" filter chip — while every attempt
  /// to open one failed with a 403, because Docs/Sheets/Slides have no binary content to fetch.
  /// They have to be exported to a concrete format instead.
  static bool isGoogleNative(drive.File f) =>
      (f.mimeType ?? '').startsWith('application/vnd.google-apps.') && !isFolder(f);

  /// The export MIME type to use for a Google-native file, or null if it is not exportable.
  static String? exportMimeFor(drive.File f) => switch (f.mimeType) {
        'application/vnd.google-apps.document' => 'application/pdf',
        'application/vnd.google-apps.spreadsheet' => 'application/pdf',
        'application/vnd.google-apps.presentation' => 'application/pdf',
        'application/vnd.google-apps.drawing' => 'application/pdf',
        _ => null,
      };

  /// Creates a folder, optionally inside [parentId]. Returns the new folder's id.
  ///
  /// Uploads have always been able to create the app's own folder via [_ensureFolder]; the
  /// screen had no way to make one, because it could not show folders at all.
  Future<String> createFolder(String name, {String? parentId}) async {
    final authClient = await _signIn.authenticatedClient();
    if (authClient == null) throw Exception('Failed to get authenticated Drive client');
    try {
      final folder = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parentId != null ? [parentId] : null;
      final created = await drive.DriveApi(authClient).files.create(folder);
      return created.id!;
    } finally {
      authClient.close();
    }
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
