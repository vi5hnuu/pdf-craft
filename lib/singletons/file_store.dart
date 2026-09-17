import 'package:flutter/foundation.dart';

/// App-wide "the files on disk changed" signal.
///
/// Every screen that lists files used to decide for itself when to re-scan, and all of them
/// decided "once, in initState". The Files tab lives inside a `StatefulShellRoute`, so it is
/// kept alive across tab switches — running a tool wrote a PDF that the tab never noticed, and
/// Recent Files / the Processed count stayed wrong until the app was restarted.
///
/// Rather than have each screen poll or guess, the few places that actually write, delete,
/// rename or move a file announce it here, and the listing screens listen. One reason to
/// change, in one place.
///
/// Deliberately carries no payload: the listings re-scan their own directories, so a path would
/// only tempt callers into partial, drifting updates of their own copies.
class FileStore extends ChangeNotifier {
  FileStore._();
  static final FileStore _instance = FileStore._();
  factory FileStore() => _instance;

  /// Call after a file has been created, overwritten, renamed, moved or deleted.
  void changed() => notifyListeners();
}
