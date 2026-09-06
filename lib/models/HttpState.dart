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

  /// Builds an error state from a Dio failure, preferring the API's own message.
  ///
  /// pdf-studio-api returns `{"success": false, "code": ..., "message": ...}` on every
  /// failure. Previously only `DioException.message` was used, which is Dio's own generic
  /// text ("Http status error [402]"), so the server's actual explanation — why the file
  /// was rejected, how many credits a tool costs — never reached the user.
  factory HttpState.fromDio(DioException e, String fallback) {
    return HttpState.error(
      error: _serverMessage(e) ?? e.message ?? fallback,
      statusCode: e.response?.statusCode,
    );
  }

  /// True when the failure was "not enough credits".
  bool get isOutOfCredits => statusCode == 402;

  static String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return null;
  }
}
