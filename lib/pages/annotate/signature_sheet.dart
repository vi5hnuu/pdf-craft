/// Capture a signature without leaving the annotate screen.
///
/// The Sign tool is a whole separate trip: pick the file again, draw, place, save. When the point
/// is "sign this bit of the page I am already looking at", that is three screens too many. This is
/// the same capture — drawn strokes exported cropped to their ink bounds on a transparent
/// background, the way [SignPdfView] does it — offered as a sheet, with the last signature
/// remembered so the common case is one tap.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/signature_store.dart';
import 'package:pdf_craft/theme/app_radius.dart';

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
  final List<List<Offset>> _strokes = [];
  Color _ink = Colors.black;
  double _width = 3;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SignatureStore().load().then((_) {
      if (mounted) setState(() {});
    });
  }

  bool get _hasInk => _strokes.any((s) => s.isNotEmpty);

  /// Exports cropped to the ink bounds on a transparent background.
  ///
  /// Not the whole canvas: a signature drawn small in the corner of a wide pad would otherwise be
  /// placed as a mostly-empty image, so it lands on the page tiny and off-centre.
  Future<Uint8List?> _export() async {
    if (!_hasInk) return null;

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final s in _strokes) {
      for (final p in s) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    final pad = _width * 2;
    final rect = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
    if (rect.width <= 0 || rect.height <= 0) return null;

    // 3x so the signature is not soft once it is scaled onto a page.
    const scale = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.translate(-rect.left, -rect.top);
    _SignaturePainter(_strokes, _ink, _width).paint(canvas, rect.size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
        (rect.width * scale).ceil(), (rect.height * scale).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _useDrawn() async {
    setState(() => _busy = true);
    final bytes = await _export();
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
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.surface),
                border: Border.all(color: theme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                child: Stack(children: [
                  // A guide line, like a signing pad.
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 44,
                    child: Container(height: 1, color: Colors.black12),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                      onPanUpdate: (d) => setState(() {
                        if (_strokes.isNotEmpty) _strokes.last.add(d.localPosition);
                      }),
                      child: CustomPaint(
                        painter: _SignaturePainter(_strokes, _ink, _width),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              for (final c in [Colors.black, Colors.blue.shade900, Colors.red.shade900])
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
                          color: _ink == c ? theme.colorScheme.primary : Colors.transparent,
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
              TextButton(
                onPressed: _hasInk ? () => setState(_strokes.clear) : null,
                child: Text(l.annotateClear),
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
                child: FilledButton(
                  onPressed: (_hasInk && !_busy) ? _useDrawn : null,
                  child: Text(l.annotateUseSignature),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.color, this.width);

  final List<List<Offset>> strokes;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final s in strokes) {
      if (s.isEmpty) continue;
      if (s.length == 1) {
        canvas.drawCircle(s.first, width / 2, Paint()..color = color);
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length; i++) {
        path.lineTo(s[i].dx, s[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes.length != strokes.length ||
      old.color != color ||
      old.width != width ||
      (strokes.isNotEmpty && old.strokes.isNotEmpty &&
          old.strokes.last.length != strokes.last.length);
}
