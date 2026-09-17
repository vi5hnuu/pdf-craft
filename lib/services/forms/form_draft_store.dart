import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:form_engine/form_engine.dart' as engine;
import 'package:path_provider/path_provider.dart';

/// Keeps a form layout on the device between sessions.
///
/// Placing thirty fields on a contract is real work, and before this a back
/// press or a mistaken tap threw all of it away. The draft is the editor's own
/// document (page-relative coordinates, no backend knowledge), so it can be
/// reopened against the same PDF and exported again without re-placing anything.
///
/// Drafts live in the app's support directory rather than shared storage: they
/// describe a user's document and have no business being visible to other apps
/// or to a file browser.
class FormDraftStore {
  static const _codec = engine.SchemaCodec();

  /// Directory holding the drafts. Injected so the store can be unit-tested
  /// against a temporary directory instead of a real device path.
  final Directory directory;

  const FormDraftStore(this.directory);

  /// The store used by the app.
  static Future<FormDraftStore> forApp() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/form_drafts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return FormDraftStore(dir);
  }

  /// Draft file for a source PDF.
  ///
  /// Named by a hash of the path, not the path itself: file names must not leak
  /// a user's folder structure or document titles into a directory listing, and
  /// a hash is a safe, fixed-length name.
  File _fileFor(String pdfPath) {
    final key = sha256.convert(utf8.encode(pdfPath)).toString().substring(0, 32);
    return File('${directory.path}/$key.json');
  }

  Future<bool> hasDraft(String pdfPath) => _fileFor(pdfPath).exists();

  Future<void> save(String pdfPath, engine.FormSchema schema) async {
    // An empty layout is not worth keeping — and writing one would make the
    // editor offer to "restore" nothing on the next open.
    if (schema.fields.isEmpty) {
      await delete(pdfPath);
      return;
    }
    final payload = {
      'saved_at': DateTime.now().toIso8601String(),
      'source': pdfPath,
      'schema': _codec.encode(schema),
    };
    await _fileFor(pdfPath).writeAsString(jsonEncode(payload));
  }

  /// Returns the stored layout, or null when there is none.
  ///
  /// A draft that cannot be read (truncated write, or written by a newer build)
  /// is deleted and treated as absent: the alternative is an editor that fails
  /// to open the document at all.
  Future<engine.FormSchema?> load(String pdfPath) async {
    final file = _fileFor(pdfPath);
    if (!await file.exists()) return null;
    try {
      final payload = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return _codec.decode((payload['schema'] as Map).cast<String, Object?>());
    } catch (_) {
      await file.delete();
      return null;
    }
  }

  Future<void> delete(String pdfPath) async {
    final file = _fileFor(pdfPath);
    if (await file.exists()) await file.delete();
  }

  /// Removes drafts untouched for [maxAge], so abandoned layouts do not sit on
  /// the device forever.
  Future<void> pruneOlderThan(Duration maxAge) async {
    if (!await directory.exists()) return;
    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) await entity.delete();
    }
  }
}
