/// Naming the file a tool just produced.
///
/// The name is proposed by the server in a `Content-Disposition` header, which makes it the one
/// input to the save path the app does not control. By the time it is used the credit has
/// already been spent, so anything that makes the name unusable costs the user their result —
/// which is why this lives on its own and is tested directly.
library;

import 'dart:io';

/// The filename a `Content-Disposition` header proposes, or null when it proposes nothing the
/// app can safely use. Never throws.
String? filenameFromContentDisposition(String? header) {
  if (header == null || header.isEmpty) return null;

  // Prefer the extended (filename*) form when present.
  final ext =
      RegExp(r"filename\*\s*=\s*[^']*''([^;]+)", caseSensitive: false).firstMatch(header);
  if (ext != null) {
    final raw = ext.group(1)!.trim();
    String decoded;
    try {
      decoded = Uri.decodeComponent(raw);
    } catch (_) {
      // Deliberately untyped. Uri.decodeComponent throws ArgumentError("Invalid URL encoding")
      // for '%ZZ', not the FormatException its name suggests — I caught the wrong type first and
      // the test above is what found it. Either way it used to throw straight out of here, past
      // the save and its fallback, losing a result the user had already paid for. The raw value
      // is a better guess than nothing, and sanitising below decides whether it is usable.
      decoded = raw;
    }
    final safe = sanitizeOutputName(decoded);
    if (safe.isNotEmpty) return safe;
  }

  final plain =
      RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false).firstMatch(header);
  if (plain != null) {
    final safe = sanitizeOutputName(plain.group(1)!.trim());
    if (safe.isNotEmpty) return safe;
  }
  return null;
}

/// [name] reduced to something that can actually be created inside a directory, or '' when
/// nothing usable is left — which tells the caller to fall back to its own generated name.
///
/// Strips any path separators, so a header naming `../../secrets.pdf` writes `secrets.pdf` here
/// rather than anywhere else. `.` and `..` are rejected outright: both survive the strip and
/// both resolve to a *directory*, so writing to them failed at the last moment with the bytes
/// already in hand.
String sanitizeOutputName(String name) {
  final last = name.split(RegExp(r'[\\/]')).last.trim();
  if (last.isEmpty || last == '.' || last == '..') return '';
  return last;
}

/// A path inside [dir] for [name] that does not collide, appending " (n)" before the extension
/// until it is free.
String uniquePath(String dir, String name) {
  var candidate = File('$dir/$name');
  if (!candidate.existsSync()) return candidate.path;
  final dot = name.lastIndexOf('.');
  final base = dot == -1 ? name : name.substring(0, dot);
  final ext = dot == -1 ? '' : name.substring(dot);
  var n = 1;
  do {
    candidate = File('$dir/$base ($n)$ext');
    n++;
  } while (candidate.existsSync());
  return candidate.path;
}
