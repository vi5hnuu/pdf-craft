import 'package:flutter/services.dart';

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

  /// File paths from the launch intent (empty if the app wasn't opened with a
  /// file). Safe to call once on startup; the native side clears them after.
  Future<List<String>> getInitialFiles() async {
    final result =
        await _method.invokeMethod<List<dynamic>>('getInitialFiles');
    return result?.cast<String>() ?? const [];
  }

  /// Files shared into the app while it is already running.
  Stream<List<String>> get stream => _events
      .receiveBroadcastStream()
      .map((event) => (event as List<dynamic>).cast<String>());
}
