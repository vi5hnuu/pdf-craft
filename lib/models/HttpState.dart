import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class HttpState {
  final bool loading;
  final double? progress; // null = indeterminate, 0.0–1.0 = determinate upload progress
  final String? error;

  /// HTTP status of a failed call, when there was a response.
  ///
  /// Carried so callers can react to a specific failure — notably 402 (out of credits) —
  /// by status rather than by searching the message text for the word "credit", which
  /// breaks the moment the server rewords anything.
  final int? statusCode;

  final bool? done;
  final Map<String, Object>? extras;

  const HttpState({
    this.loading = false,
    this.progress,
    this.error,
    this.statusCode,
    this.done,
    this.extras,
  });

  const HttpState.loading({this.progress})
      : loading = true,
        error = null,
        statusCode = null,
        done = null,
        extras = null;

  const HttpState.done({Map<String, Object>? extras})
      : this(done: true, extras: extras);

  const HttpState.error({required String? error, int? statusCode})
      : this(loading: false, error: error, statusCode: statusCode);

  // User-facing transport failures. Kept here so every tool reports them the same way.
  static const String msgUnreachable =
      "Couldn't reach the server. Check your connection and try again.";
  static const String msgTimeout = 'The server took too long to respond. Please try again.';
  static const String msgTooLarge = 'This file is larger than the upload limit. Try a smaller file.';
  static const String msgInterrupted =
      'Upload interrupted — the file may be too large or the connection dropped. Please try again.';

  /// Builds an error state from a Dio failure.
  ///
  /// Order of preference:
  ///  1. the API's own message (`{"success": false, "message": ...}`), which explains *why*;
  ///  2. a clear description of a transport failure (offline, timeout, too large, dropped);
  ///  3. the tool's [fallback] ("Failed to compress PDF").
  ///
  /// Dio's raw `message` ("Http status error [402]", "HttpException: Connection closed…") is
  /// never shown — it is meaningless to users.
  factory HttpState.fromDio(DioException e, String fallback) {
    return HttpState.error(
      error: _serverMessage(e) ?? _transportMessage(e) ?? fallback,
      statusCode: e.response?.statusCode,
    );
  }

  /// True when the failure was "not enough credits".
  bool get isOutOfCredits => statusCode == 402;

  static String? _serverMessage(DioException e) {
    var data = e.response?.data;
    // File tools request `ResponseType.bytes`, so an error body arrives as raw bytes rather than
    // a decoded map. Decode it, otherwise the server's explanation is silently lost.
    if (data is List<int>) {
      try {
        data = jsonDecode(utf8.decode(data));
      } catch (_) {
        return null;
      }
    }
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return null;
  }

  static String? _transportMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return msgTimeout;
      case DioExceptionType.connectionError:
        // The offline interceptor (DioSingleton) rejects with its own friendly text; keep it.
        final m = e.message;
        return (m != null && m.startsWith('No internet')) ? m : msgUnreachable;
      case DioExceptionType.badResponse:
        return e.response?.statusCode == 413 ? msgTooLarge : null;
      case DioExceptionType.unknown:
        // The server (or a proxy) closing the socket mid-upload surfaces as an I/O error.
        return (e.error is HttpException || e.error is SocketException) ? msgInterrupted : null;
      default:
        return null;
    }
  }
}
