import 'dart:io';

/// Lightweight connectivity check using a DNS lookup.
/// No extra package needed — uses dart:io only.
class NetworkUtils {
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
