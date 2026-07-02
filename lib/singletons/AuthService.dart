import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pdf_craft/models/auth/AuthUser.dart';
import 'package:pdf_craft/services/auth/AuthApi.dart';
import 'package:pdf_craft/services/auth/TokenStorage.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';

/// Owns the app's authentication state and tokens.
///
/// The app is guest-first: [bootstrap] silently creates an anonymous account on first
/// launch so every product request has a valid token. Users can later [login],
/// [register] or [signInWithGoogle] to a full account. The shared Dio interceptor reads
/// [accessTokenSync] and calls [refreshAccessToken] on a 401.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._();
  AuthService._();
  factory AuthService() => _instance;

  final AuthApi _api = AuthApi();
  final TokenStorage _storage = TokenStorage();

  AuthUser? _user;
  String? _accessToken; // in-memory copy for the sync interceptor read
  Future<String?>? _inFlightRefresh; // single-flight guard

  AuthUser? get user => _user;
  bool get isGuest => _user?.isGuest ?? true;
  bool get isSignedInFull => _user != null && !_user!.isGuest;
  String? get accessTokenSync => _accessToken;

  /// Loads persisted tokens, or creates a guest session if none exist.
  Future<void> bootstrap() async {
    _accessToken = await _storage.accessToken;
    final userId = await _storage.userId;
    if (_accessToken == null || userId == null) {
      await _createGuest();
      return;
    }
    // We have tokens; trust them until a request 401s and triggers a refresh.
    // (Minimal profile until /me or the next auth response fills it in.)
    _user = AuthUser(id: userId, accountType: 'USER', authProvider: 'LOCAL', enabled: true);
    notifyListeners();
  }

  Future<void> _createGuest() async {
    final data = await _api.createGuest();
    await _applyTokens(data);
  }

  // ── Full-account flows ────────────────────────────────────────────────────────

  Future<void> login(String identifier, String password) async {
    final data = await _api.login(identifier, password);
    await _applyTokens(data);
  }

  /// Returns the server message (account created, verify e-mail).
  Future<String> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? username,
  }) =>
      _api.register(
          email: email, password: password,
          firstName: firstName, lastName: lastName, username: username);

  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(scopes: const ['email']);
    final account = await googleSignIn.signIn();
    if (account == null) throw AuthException('Google sign-in cancelled.');
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw AuthException('Could not obtain Google credentials.');
    final data = await _api.googleLogin(idToken);
    await _applyTokens(data);
  }

  /// Upgrades the current guest into a full account, preserving the userId (and thus
  /// the credit balance). The existing tokens stay valid; the user should verify e-mail.
  /// Returns the server-facing next step message.
  Future<String> convertGuest({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final token = _accessToken;
    if (token == null) throw AuthException('No active session.');
    final data = await _api.convert(token,
        email: email, password: password, firstName: firstName, lastName: lastName);
    _user = AuthUser.fromJson(data);
    notifyListeners();
    return 'Account created. Check your e-mail to verify it.';
  }

  Future<String> forgotPassword(String email) => _api.forgotPassword(email);

  /// Signs out to a fresh guest session so the app stays usable.
  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    if (refresh != null) await _api.logout(refresh);
    await _storage.clear();
    _accessToken = null;
    _user = null;
    await _createGuest();
  }

  // ── Token refresh (called by the Dio interceptor on 401) ───────────────────────

  /// Refreshes the access token, single-flighted so concurrent 401s share one call.
  /// Falls back to a new guest session if the refresh token is invalid/expired.
  Future<String?> refreshAccessToken() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(() => _inFlightRefresh = null);
  }

  Future<String?> _doRefresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null) {
      await _createGuest();
      return _accessToken;
    }
    try {
      final data = await _api.refresh(refresh);
      await _applyTokens(data);
      return _accessToken;
    } catch (e) {
      LoggerSingleton().logger.w('Refresh failed, falling back to guest: $e');
      await _storage.clear();
      await _createGuest();
      return _accessToken;
    }
  }

  // ── shared ──────────────────────────────────────────────────────────────────

  Future<void> _applyTokens(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String;
    final userJson = (data['user'] as Map).cast<String, dynamic>();
    _user = AuthUser.fromJson(userJson);
    _accessToken = access;
    await _storage.save(accessToken: access, refreshToken: refresh, userId: _user!.id);
    notifyListeners();
  }
}
