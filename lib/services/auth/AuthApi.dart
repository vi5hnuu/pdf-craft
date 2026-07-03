import 'package:dio/dio.dart';
import 'package:pdf_craft/utils/Constants.dart';

/// Thrown when the auth service rejects a request; [message] is the human-readable
/// reason from the server envelope (safe to show to the user).
class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Thin client for the standalone auth service. Uses its own [Dio] (not the shared
/// [DioSingleton]) so the access-token/refresh interceptor never applies to auth calls
/// themselves — avoiding recursion during token refresh.
class AuthApi {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: Constants.authBaseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    // Scope every token this app requests to our product (aud claim).
    headers: {'X-Audience': Constants.apiAudience},
  ));

  /// POST /auth/guest → token bundle (data).
  Future<Map<String, dynamic>> createGuest() => _postData('/auth/guest');

  Future<Map<String, dynamic>> login(String identifier, String password) =>
      _postData('/auth/login', {'identifier': identifier, 'password': password});

  Future<Map<String, dynamic>> googleLogin(String idToken) =>
      _postData('/auth/login/google', {'idToken': idToken});

  Future<Map<String, dynamic>> refresh(String refreshToken) =>
      _postData('/auth/refresh', {'refreshToken': refreshToken});

  /// GET /user/me → the authenticated user's profile (data).
  Future<Map<String, dynamic>> getMe(String accessToken) async {
    try {
      final res = await _dio.get('/user/me',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      return (res.data['data'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _asAuthException(e);
    }
  }

  /// Register returns no tokens (account starts unverified) — returns the server message.
  Future<String> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? username,
  }) =>
      _postMessage('/auth/register', {
        'email': email,
        'password': password,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (username != null && username.isNotEmpty) 'username': username,
      });

  /// Convert the current guest (Bearer set by caller) into a full account.
  Future<Map<String, dynamic>> convert(
    String accessToken, {
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final res = await _dio.post('/auth/convert',
          data: {
            'email': email,
            'password': password,
            if (firstName != null) 'firstName': firstName,
            if (lastName != null) 'lastName': lastName,
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      return (res.data['data'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _asAuthException(e);
    }
  }

  Future<String> forgotPassword(String email) =>
      _postMessage('/auth/forgot-password', {'email': email});

  Future<String> reVerify(String email) =>
      _postMessage('/auth/re-verify', {'email': email});

  /// PATCH /user/me/password — change password of a full (LOCAL) account.
  Future<void> changePassword(String accessToken, String oldPassword, String newPassword) async {
    try {
      await _dio.patch('/user/me/password',
          data: {'oldPassword': oldPassword, 'newPassword': newPassword},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
    } on DioException catch (e) {
      throw _asAuthException(e);
    }
  }

  /// DELETE /user/me — soft-delete the current account.
  Future<void> deleteAccount(String accessToken) async {
    try {
      await _dio.delete('/user/me',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
    } on DioException catch (e) {
      throw _asAuthException(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {/* best-effort */}
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _postData(String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await _dio.post(path, data: body);
      return (res.data['data'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _asAuthException(e);
    }
  }

  Future<String> _postMessage(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post(path, data: body);
      return res.data['message'] as String? ?? 'Done.';
    } on DioException catch (e) {
      throw _asAuthException(e);
    }
  }

  AuthException _asAuthException(DioException e) {
    // Connection-level failures (server unreachable / timeout) → clear connectivity message
    // instead of a generic error, so the user knows it's the network, not their input.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return AuthException(
            "Couldn't reach the server. Check your connection and try again.");
      default:
        break;
    }
    // Prefer the server's human-readable message from the {success,message,data} envelope.
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return AuthException(data['message'] as String, e.response?.statusCode);
    }
    // Fall back to a status-appropriate message.
    final code = e.response?.statusCode ?? 0;
    final fallback = switch (code) {
      401 => 'Invalid credentials.',
      403 => 'This action is not allowed.',
      409 => 'That account already exists.',
      >= 500 => 'The server had a problem. Please try again shortly.',
      _ => 'Something went wrong. Please try again.',
    };
    return AuthException(fallback, e.response?.statusCode);
  }
}
