import 'package:flutter/services.dart';

/// What an incoming intent actually delivered.
///
/// [attempted] is how many files the intent carried; [paths] are the ones that could be copied
/// into the app's cache. They differ when a file cannot be read — a permission that was not
/// granted, a URI that points at a directory, a provider that has already revoked access. That
/// case used to be indistinguishable from "nothing was shared", so the app did nothing at all
/// and the user was left looking at whatever happened to be on screen.
class IncomingFiles {
  const IncomingFiles({required this.paths, required this.attempted});

  final List<String> paths;
  final int attempted;

  /// The intent carried files and not one of them could be read.
  bool get allFailed => paths.isEmpty && attempted > 0;

  bool get isEmpty => paths.isEmpty;
}

/// Dart side of the native incoming-files platform channel (see MainActivity.kt).
///
/// Exposes files opened into the app from other apps ("Open with" / share
/// sheet). [getInitialFiles] returns the file(s) that cold-started the app;
/// [stream] emits files delivered while the app is already running. Paths point
/// at app-cache copies the native side made, so they can be read directly.
class IncomingFilesChannel {
  IncomingFilesChannel._();
  static final IncomingFilesChannel instance = IncomingFilesChannel._();

  static const _method =
      MethodChannel('com.vi5hnu.pdf_craft/incoming_files');
  static const _events =
      EventChannel('com.vi5hnu.pdf_craft/incoming_files_events');

  /// Files from the launch intent. Safe to call once on startup; the native side clears them
  /// after.
  Future<IncomingFiles> getInitialFiles() async {
    final result = await _method.invokeMapMethod<String, dynamic>('getInitialFiles');
    return _parse(result);
  }

  /// Files shared into the app while it is already running.
  Stream<IncomingFiles> get stream => _events
      .receiveBroadcastStream()
      .map((event) => _parse((event as Map?)?.cast<String, dynamic>()));

  static IncomingFiles _parse(Map<String, dynamic>? raw) => IncomingFiles(
        paths: (raw?['paths'] as List?)?.cast<String>() ?? const [],
        attempted: (raw?['attempted'] as int?) ?? 0,
      );
}
