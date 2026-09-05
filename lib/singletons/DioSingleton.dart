import 'dart:math';

import 'package:dio/dio.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/utils/NetworkUtils.dart';

class DioSingleton {
  final Dio dio = Dio();
  static final DioSingleton _instance = DioSingleton._();

  DioSingleton._() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Reject immediately if device has no internet — avoids confusing timeout errors
        if (!await NetworkUtils.isOnline()) {
          return handler.reject(DioException(
            requestOptions: options,
            message: 'No internet connection. Please check your network.',
            type: DioExceptionType.connectionError,
          ));
        }
        // Attach the current access token so pdf-studio can authenticate the request.
        // If none yet (cold start / first launch), establish one first so the request
        // never goes out unauthenticated.
        var token = AuthService().accessTokenSync;
        token ??= await AuthService().ensureSession();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Give every mutating call a stable key so a retry — ours after a 401, or the
        // user's after a timeout — is charged once, not twice. The server enforces this
        // with a unique constraint on (userId, idempotencyKey); previously only the
        // rewarded-ad call sent one, so a retried tool run was billed again.
        //
        // Assigned once per RequestOptions: a retry reuses the same object and therefore
        // the same key, which is precisely what makes it idempotent.
        if (options.method.toUpperCase() != 'GET' &&
            !options.headers.containsKey('Idempotency-Key')) {
          options.headers['Idempotency-Key'] = _idempotencyKey();
        }
        LoggerSingleton().logger.i('REQUEST [${options.method}] => PATH: ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        LoggerSingleton().logger.i('RESPONSE [${response.statusCode}] => PATH: ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        // On a 401, refresh the token once and transparently retry the request.
        if (e.response?.statusCode == 401 && e.requestOptions.extra['__retried'] != true) {
          final newToken = await AuthService().refreshAccessToken();
          if (newToken != null) {
            try {
              final req = e.requestOptions;
              req.extra['__retried'] = true;
              req.headers['Authorization'] = 'Bearer $newToken';
              // FormData bodies are single-use (their streams are consumed on send);
              // clone before retrying or the re-upload would send an empty/corrupt body.
              if (req.data is FormData) {
                req.data = (req.data as FormData).clone();
              }
              final response = await dio.fetch(req);
              return handler.resolve(response);
            } catch (retryErr) {
              LoggerSingleton().logger.w('Retry after refresh failed: $retryErr');
            }
          }
        }
        LoggerSingleton().logger.e('ERROR [${e.response?.statusCode}] => PATH: ${e.requestOptions.path}', error: e.error);
        return handler.next(e);
      },
    ));
  }

  factory DioSingleton() {
    return _instance;
  }

  /// Random enough that two devices never collide, short enough for the server's
  /// idempotency_key column (VARCHAR(100)).
  static String _idempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}-$hex';
  }
}
