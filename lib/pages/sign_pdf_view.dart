import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/widgets/ink/drawing_pad.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// Create a signature — either by drawing it or importing an image — then
/// navigate to PlaceImageView to drag/resize and stamp it onto the PDF.
///
/// The drawn signature is exported **cropped to its ink bounds with a
/// transparent background** (previously the whole white canvas was captured, so
/// the signature ended up tiny inside a large white block). Strokes are smoothed
/// with quadratic beziers for a natural pen feel.
class SignPdfView extends StatefulWidget {
  final File file;
  const SignPdfView({super.key, required this.file});

  @override
  State<SignPdfView> createState() => _SignPdfViewState();
}

class _SignPdfViewState extends State<SignPdfView> {
  // Drawing lives in the shared pad, which is also what the signature sheet inside Annotate
  // uses — so a fix to either reaches both. This screen's own copy joined points with straight
  // lines, and its gesture area was not opaque, so on some layouts it captured nothing at all.
  final DrawingPadController _pad = DrawingPadController();
  Color _inkColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _busy = false;

  static const _colorOptions = [
    Colors.black,
    Color(0xFF1565C0), // blue-ink
    Color(0xFFC62828), // red-ink
  ];

  bool get _hasStrokes => !_pad.isEmpty;

  @override
  void dispose() {
    _pad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(ToolStrings.name(context, 'sign')),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: L10n.of(context).undo,
            onPressed: _pad.canUndo ? _pad.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: L10n.of(context).clear,
            onPressed: _hasStrokes ? _pad.clear : null,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(
                L10n.of(context).signHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 12),
              // Signature canvas — a card with a guide line, like a signing pad.
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.surface),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    // Signature guide line.
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 48,
                      child: Row(children: [
                        Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Expanded(child: Container(height: 1.5, color: Colors.grey.shade300)),
                      ]),
                    ),
                    if (!_hasStrokes)
                      Center(
                        child: Text(L10n.of(context).signHere,
                            style: TextStyle(color: Colors.grey.shade300, fontSize: 28, fontStyle: FontStyle.italic)),
                      ),
                    DrawingPad(
                      controller: _pad,
                      color: _inkColor,
                      width: _strokeWidth,
                      background: Colors.transparent,
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        // Ink controls.
        Container(
          color: theme.cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            ..._colorOptions.map((c) => GestureDetector(
                  onTap: () => setState(() => _inkColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _inkColor == c ? theme.colorScheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                )),
            const SizedBox(width: 8),
            Icon(Icons.line_weight, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            Expanded(
              child: Slider(
                value: _strokeWidth,
                min: 1.0,
                max: 8.0,
                divisions: 7,
                label: _strokeWidth.round().toString(),
                onChanged: (v) => setState(() => _strokeWidth = v),
              ),
            ),
          ]),
        ),
        // Actions.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _importSignature,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(L10n.of(context).importLabel),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (_hasStrokes && !_busy) ? _placeDrawn : null,
                  icon: const Icon(Icons.check),
                  label: Text(L10n.of(context).placeOnPdf),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _placeDrawn() async {
    setState(() => _busy = true);
    try {
      final bytes = await _exportCroppedSignature();
      if (bytes == null) {
        NotificationService.showSnackbar(text: L10n.current.signatureCaptureFailed, color: Colors.red);
        return;
      }
      if (!mounted) return;
      GoRouter.of(context).pushNamed(
        AppRoutes.placeImageRoute.name,
        extra: {'file': widget.file, 'imageBytes': bytes, 'title': L10n.of(context).placeSignature},
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSignature() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;
    GoRouter.of(context).pushNamed(
      AppRoutes.placeImageRoute.name,
      extra: {'file': widget.file, 'imageBytes': bytes, 'title': L10n.of(context).placeSignature},
    );
  }

  /// Renders only the drawn strokes, cropped to their bounding box with padding
  /// and a transparent background, at 3x for crisp stamping.
  /// Delegates to the shared pad, which crops to the ink bounds for the same reason this used
  /// to: a signature drawn small in a big pad, exported whole, lands on the page tiny.
  Future<Uint8List?> _exportCroppedSignature() => _pad.exportPng();
}

