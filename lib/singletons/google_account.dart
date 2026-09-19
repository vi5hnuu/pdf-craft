import 'package:google_sign_in/google_sign_in.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/utils/constants.dart';

/// The app's single Google session.
///
/// There is only ever one Google account signed in to an app, whatever the Dart code looks
/// like. `google_sign_in_android` keeps one `GoogleSignInClient` field and reconfigures it on
/// every `init`, so two `GoogleSignIn` objects do not give you two sessions — they give you one
/// session whose configuration is whichever object was constructed last.
///
/// This app had exactly that: sign-in used `scopes: ['email']` with a `serverClientId`, Drive
/// used the Drive scopes with none. The consequences were real and order-dependent:
///
///  * Open the Cloud tab, then sign in with Google, and the ID token came back **null** —
///    the live configuration had no `serverClientId` to mint it against.
///  * Sign in with Google, then use Drive, and the session could be missing the Drive scopes.
///  * `signOut()` reaches the one native client, so signing out of *either* concern signed out
///    of both, while the other's cached `GoogleSignInAccount` stayed non-null in Dart and only
///    failed later, at the next API call.
///
/// One instance, configured once, with Drive's scopes requested incrementally when the user
/// actually opens Cloud. That also keeps the consent screen honest: asking for Drive access
/// while somebody is only trying to log in is a good way to lose them.
class GoogleAccount {
  GoogleAccount._();
  static final GoogleAccount _instance = GoogleAccount._();
  factory GoogleAccount() => _instance;

  /// Basic scopes only. `serverClientId` is what makes `authentication.idToken` non-null; it
  /// belongs here rather than on one of two competing instances.
  final GoogleSignIn _client = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: Constants.googleWebClientId,
  );

  /// The underlying plugin instance, for the extension that builds an authenticated HTTP
  /// client. Nothing else should construct a [GoogleSignIn].
  GoogleSignIn get client => _client;

  GoogleSignInAccount? get current => _client.currentUser;

  /// The signed-in account without any UI, or null if there is none.
  Future<GoogleSignInAccount?> restore() async {
    try {
      return await _client.signInSilently();
    } catch (e) {
      LoggerSingleton().logger.w('Google silent sign-in unavailable: $e');
      return null;
    }
  }

  /// Signs in, showing the account picker only when there is no account to reuse.
  ///
  /// [forcePicker] drops the cached account first so the picker always appears — for an
  /// explicit "use a different account". It is not the default because it signs the app out of
  /// Google wholesale, which takes any connected Drive session with it; that is the right
  /// outcome when somebody deliberately switches account, and the wrong one as a side effect
  /// of an ordinary login.
  Future<GoogleSignInAccount?> signIn({bool forcePicker = false}) async {
    if (forcePicker) await signOut();
    return _client.signInSilently().then((a) => a ?? _client.signIn());
  }

  /// Interactive sign-in that always shows the picker.
  Future<GoogleSignInAccount?> switchAccount() => signIn(forcePicker: true);

  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (e) {
      // Never let Google being unavailable block signing out of the app itself.
      LoggerSingleton().logger.w('Google sign-out failed: $e');
    }
  }

  /// Ensures the session carries [scopes], prompting for consent if it does not.
  ///
  /// Incremental authorisation: Drive access is asked for when Drive is opened, not bundled
  /// into the login. Returns false when the user declines, so the caller can say so instead of
  /// failing later inside an API call.
  Future<bool> ensureScopes(List<String> scopes) async {
    // `canAccessScopes` is a fast path that only iOS and web implement; `google_sign_in_android`
    // does not, so on Android the base class throws UnimplementedError. Catching that alongside
    // everything else and returning false meant Drive could never obtain its scopes on Android
    // at all — the one platform this app ships on.
    try {
      if (await _client.canAccessScopes(scopes)) return true;
    } on UnimplementedError {
      // Expected on Android. requestScopes below is implemented everywhere and already returns
      // true without prompting when the scopes are held, so it is a complete substitute.
    } catch (e) {
      LoggerSingleton().logger.w('Google scope check failed, asking instead: $e');
    }

    try {
      return await _client.requestScopes(scopes);
    } catch (e) {
      LoggerSingleton().logger.w('Google scope request failed: $e');
      return false;
    }
  }
}
