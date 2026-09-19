/// Capture a signature without leaving the annotate screen.
///
/// The Sign tool is a whole separate trip: pick the file again, draw, place, save. When the point
/// is "sign this bit of the page I am already looking at", that is three screens too many.
///
/// The drawing itself is [DrawingPad], shared with the Sign tool — including the two fixes that
/// made it work at all: an opaque hit-test area, and a painter that repaints on a revision
/// counter rather than on a list it mutates in place.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/signature_store.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/widgets/ink/drawing_pad.dart';

class SignatureSheet extends StatefulWidget {
  const SignatureSheet({super.key});

  /// Returns the signature as PNG bytes, or null if the user backed out.
  static Future<Uint8List?> show(BuildContext context) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.surface))),
      builder: (_) => const SignatureSheet(),
    );
  }

  @override
  State<SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<SignatureSheet> {
  final _pad = DrawingPadController();
  Color _ink = Colors.black;
  double _width = 3;
  bool _busy = false;

  /// Ink colours worth offering: the three a signature is actually made in.
  static const _inks = [Color(0xFF000000), Color(0xFF0D47A1), Color(0xFFB71C1C)];

  @override
  void initState() {
    super.initState();
    SignatureStore().load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pad.dispose();
    super.dispose();
  }

  Future<void> _useDrawn() async {
    setState(() => _busy = true);
    final bytes = await _pad.exportPng();
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null) return;
    await SignatureStore().save(bytes);
    if (mounted) Navigator.pop(context, bytes);
  }

  Future<void> _import() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    final bytes = await File(path).readAsBytes();
    if (!mounted) return;
    await SignatureStore().save(bytes);
    if (mounted) Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L10n.of(context);
    final saved = SignatureStore().signature;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(children: [
              Icon(Icons.draw_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(l.annotateAddSignature,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600))),
              // Undo and redo, driven by the pad. A signature is drawn in a few strokes and the
              // last one is the one that goes wrong; without undo the only recovery was Clear,
              // which threw away the good strokes too.
              ListenableBuilder(
                listenable: _pad,
                builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: l.undo,
                    onPressed: _pad.canUndo ? _pad.undo : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    tooltip: l.redo,
                    onPressed: _pad.canRedo ? _pad.redo : null,
                  ),
                ]),
              ),
            ]),
          ),

          // The saved signature, when there is one — the whole reason this is one tap.
          if (saved != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: SizedBox(
                      width: 56, height: 32, child: Image.memory(saved, fit: BoxFit.contain)),
                  title: Text(l.annotateUseSavedSignature),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l.delete,
                    onPressed: () async {
                      await SignatureStore().clear();
                      if (context.mounted) setState(() {});
                    },
                  ),
                  onTap: () => Navigator.pop(context, saved),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                border: Border.all(color: theme.dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: DrawingPad(
                controller: _pad,
                color: _ink,
                width: _width,
                guideLine: true,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              for (final c in _inks)
                GestureDetector(
                  onTap: () => setState(() => _ink = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _ink.toARGB32() == c.toARGB32()
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2),
                    ),
                  ),
                ),
              Expanded(
                child: Slider(
                  value: _width,
                  min: 1,
                  max: 8,
                  onChanged: (v) => setState(() => _width = v),
                ),
              ),
              ListenableBuilder(
                listenable: _pad,
                builder: (context, _) => TextButton(
                  onPressed: _pad.isEmpty ? null : _pad.clear,
                  child: Text(l.annotateClear),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(l.annotateImportSignature),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListenableBuilder(
                  listenable: _pad,
                  builder: (context, _) => FilledButton(
                    onPressed: (_pad.isEmpty || _busy) ? null : _useDrawn,
                    child: Text(l.annotateUseSignature),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
