import 'dart:async';
import 'dart:convert';

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
  bool _sessionExpired = false; // a full account's session just expired

  AuthUser? get user => _user;
  bool get isGuest => _user?.isGuest ?? true;
  bool get isSignedInFull => _user != null && !_user!.isGuest;
  String? get accessTokenSync => _accessToken;

  /// True when a signed-in (full) account's session expired and the app fell back to a
  /// guest. A top-level watcher surfaces a "sign in again / continue as guest" prompt.
  bool get sessionExpired => _sessionExpired;

  /// Dismisses the session-expired signal (after the user has chosen how to proceed).
  void acknowledgeSessionExpired() {
    if (_sessionExpired) {
      _sessionExpired = false;
      notifyListeners();
    }
  }

  /// Loads persisted tokens + the real stored profile, or creates a guest session if
  /// none exist. Never fabricates account state — a restored guest stays a guest until
  /// the server says otherwise (hydration below just refreshes it).
  Future<void> bootstrap() async {
    _accessToken = await _storage.accessToken;
    if (_accessToken == null) {
      await _createGuest();
      return;
    }
    // Restore the real stored profile (if any) so we never guess account state.
    final storedUser = await _storage.userJson;
    if (storedUser != null) {
      try {
        _user = AuthUser.fromJson((jsonDecode(storedUser) as Map).cast<String, dynamic>());
      } catch (_) {/* corrupt — will be refreshed below */}
    }
    notifyListeners();
    // Refresh (or, if there was no stored profile, fetch) the real profile from the server.
    unawaited(_hydrateUser());
  }

  /// Guarantees a usable access token exists, creating a guest session (or restoring
  /// from a stored refresh token) if needed. Safe to call repeatedly and concurrently —
  /// the underlying refresh is single-flighted. Used by the Dio interceptor so a request
  /// never goes out token-less on a cold start.
  Future<String?> ensureSession() async {
    if (_accessToken != null) return _accessToken;
    return refreshAccessToken();
  }

  /// Fetches the real profile from /me and updates [user]; best-effort.
  Future<void> _hydrateUser() async {
    final token = _accessToken;
    if (token == null) return;
    try {
      await _setUser(AuthUser.fromJson(await _api.getMe(token)));
    } on AuthException catch (e) {
      if (e.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed != null) {
          try {
            await _setUser(AuthUser.fromJson(await _api.getMe(refreshed)));
          } catch (_) {/* keep stored profile */}
        }
      }
    } catch (_) {/* keep stored profile */}
  }

  /// Sets the current user, persists it, and notifies listeners.
  Future<void> _setUser(AuthUser user) async {
    _user = user;
    await _storage.saveUser(jsonEncode(user.toJson()));
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
    // Ensure a (guest) session exists to convert. If launch happened offline the guest
    // may not have been created yet — establish one now rather than failing outright.
    final token = _accessToken ?? await ensureSession();
    if (token == null) {
      throw AuthException("Couldn't reach the server. Check your connection and try again.");
    }
    final data = await _api.convert(token,
        email: email, password: password, firstName: firstName, lastName: lastName);
    await _setUser(AuthUser.fromJson(data));
    return 'Account created. Check your e-mail to verify it.';
  }

  Future<String> forgotPassword(String email) => _api.forgotPassword(email);

  Future<String> reVerify(String email) => _api.reVerify(email);

  /// Re-fetches the profile from the server (e.g. to pick up a just-completed e-mail
  /// verification). Returns true once the account is verified/enabled.
  Future<bool> refreshProfile() async {
    await _hydrateUser();
    return _user?.enabled ?? false;
  }

  /// Updates the display name (and persists the refreshed profile).
  Future<void> updateProfile({String? firstName, String? lastName}) async {
    final token = _accessToken ?? await ensureSession();
    if (token == null) {
      throw AuthException("Couldn't reach the server. Check your connection and try again.");
    }
    await _setUser(AuthUser.fromJson(
        await _api.updateProfile(token, firstName: firstName, lastName: lastName)));
  }

  /// Changes the password of a full (LOCAL) account.
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final token = _accessToken ?? await ensureSession();
    if (token == null) {
      throw AuthException("Couldn't reach the server. Check your connection and try again.");
    }
    await _api.changePassword(token, oldPassword, newPassword);
    // The server revokes every session (incl. this one's refresh token) on a password
    // change. Re-establish a fresh session with the new password so the user isn't
    // silently dropped to a guest when the current access token expires.
    final email = _user?.email;
    if (email != null) {
      try {
        await login(email, newPassword);
      } catch (_) {/* non-fatal — they can sign in manually with the new password */}
    }
  }

  /// Permanently deletes the account, then drops back to a fresh guest session.
  Future<void> deleteAccount() async {
    final token = _accessToken;
    if (token != null) {
      try {
        await _api.deleteAccount(token);
      } catch (_) {/* fall through to local cleanup */}
    }
    await _resetToGuest();
  }

  /// Signs out to a fresh guest session so the app stays usable.
  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    if (refresh != null) await _api.logout(refresh);
    await _resetToGuest();
  }

  /// Clears local session state (reflecting it immediately) then re-establishes a guest
  /// session. Resilient to being offline — a session is re-obtained lazily on the next
  /// request via [ensureSession].
  Future<void> _resetToGuest() async {
    await _storage.clear();
    _accessToken = null;
    _user = null;
    notifyListeners();
    try {
      await _createGuest();
    } catch (_) {/* lazily re-established later */}
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
    // Remember whether a *full* account is expiring, before we overwrite _user.
    final wasFull = _user != null && !_user!.isGuest;
    try {
      final data = await _api.refresh(refresh);
      await _applyTokens(data);
      return _accessToken;
    } catch (e) {
      LoggerSingleton().logger.w('Refresh failed, falling back to guest: $e');
      await _storage.clear();
      await _createGuest(); // keep the app usable
      // A real account just lost its session — flag it so the UI can offer to sign in
      // again (rather than silently leaving them as a guest).
      if (wasFull) {
        _sessionExpired = true;
        notifyListeners();
      }
      return _accessToken;
    }
  }

  // ── shared ──────────────────────────────────────────────────────────────────

  Future<void> _applyTokens(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String;
    _user = AuthUser.fromJson((data['user'] as Map).cast<String, dynamic>());
    _accessToken = access;
    await _storage.save(
        accessToken: access, refreshToken: refresh, userJson: jsonEncode(_user!.toJson()));
    notifyListeners();
  }
}
