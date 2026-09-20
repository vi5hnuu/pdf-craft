import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers one signature so it can be reused.
///
/// Signing a document used to mean drawing the signature again every single time — the Sign tool
/// captures one, places it, and forgets it. Keeping the last one is what makes "insert my
/// signature" a one-tap action rather than a redraw.
///
/// Stored as base64 PNG in SharedPreferences: a signature is a few KB, it is the user's own mark
/// rather than a credential, and it must survive an app restart. Same pattern as
/// [FavoriteToolsService].
class SignatureStore extends ChangeNotifier {
  static final SignatureStore _instance = SignatureStore._();
  SignatureStore._();
  factory SignatureStore() => _instance;

  static const _key = 'saved_signature_png';

  Uint8List? _cache;
  bool _loaded = false;

  /// Loads the saved signature into memory (idempotent), so widgets can read it during build.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    _cache = encoded == null ? null : base64Decode(encoded);
    _loaded = true;
    notifyListeners();
  }

  /// The saved signature, or null. Call [load] once first.
  Uint8List? get signature => _cache;

  bool get hasSignature => _cache != null;

  Future<void> save(Uint8List png) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, base64Encode(png));
    _cache = png;
    _loaded = true;
    notifyListeners();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cache = null;
    notifyListeners();
  }
}
