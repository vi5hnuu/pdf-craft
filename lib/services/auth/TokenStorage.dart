import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';

/// Persists the auth tokens in the platform keystore/keychain via
/// flutter_secure_storage, so they survive restarts but are not readable by
/// other apps or plain file access.
///
/// All operations are defensive: a keystore that misbehaves on some devices
/// (corrupt entry, unsupported API level, locked keychain) must never brick auth.
/// On failure reads return null and writes are dropped — the session still works
/// in-memory for its lifetime; it just may not persist across restarts.
class TokenStorage {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user_json';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Persists tokens plus the real user profile (JSON) so a restart restores the
  /// actual account state — never a guessed one.
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    await _write(_kAccess, accessToken);
    await _write(_kRefresh, refreshToken);
    await _write(_kUser, userJson);
  }

  Future<String?> get accessToken => _read(_kAccess);
  Future<String?> get refreshToken => _read(_kRefresh);
  Future<String?> get userJson => _read(_kUser);

  Future<void> updateAccessToken(String accessToken) => _write(_kAccess, accessToken);

  Future<void> updateTokens(String accessToken, String refreshToken) async {
    await _write(_kAccess, accessToken);
    await _write(_kRefresh, refreshToken);
  }

  Future<void> saveUser(String userJson) => _write(_kUser, userJson);

  Future<void> clear() async {
    await _delete(_kAccess);
    await _delete(_kRefresh);
    await _delete(_kUser);
  }

  // ── defensive wrappers ────────────────────────────────────────────────────────

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      LoggerSingleton().logger.w('Secure storage read failed ($key): $e');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      LoggerSingleton().logger.w('Secure storage write failed ($key): $e');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      LoggerSingleton().logger.w('Secure storage delete failed ($key): $e');
    }
  }
}
