import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth tokens in the platform keystore/keychain via
/// flutter_secure_storage, so they survive restarts but are not readable by
/// other apps or plain file access.
class TokenStorage {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUserId = 'auth_user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kUserId, value: userId);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);
  Future<String?> get userId => _storage.read(key: _kUserId);

  Future<void> updateAccessToken(String accessToken) =>
      _storage.write(key: _kAccess, value: accessToken);

  Future<void> updateTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUserId);
  }
}
