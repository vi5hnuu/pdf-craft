import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// Page one of a document with a tool's effect drawn over it.
///
/// Most tool screens asked for numbers — an opacity, an angle, a font size, a position —
/// and showed nothing, so the only way to find out what a setting did was to run the tool
/// and open the result. The crop, redact and place-image screens already render the page and
/// let you work on it directly; this is that same idea packaged so the settings-only screens
/// can use it without each one re-implementing the load, the fit and the scaling.
///
/// [overlayBuilder] is given the page's on-screen size in logical pixels and the page's own
/// size in PDF points, which is what an overlay needs to convert a point-based setting
/// (a 48pt watermark, a 10pt margin) into something that reads true against the render.
class PdfEffectPreview extends StatefulWidget {
  final String filePath;

  /// Draws the effect. `canvas` is the rendered page's size on screen; `pagePoints` is its
  /// size in PDF points, so `canvas.width / pagePoints.width` is the scale to apply.
  final Widget Function(BuildContext context, Size canvas, Size pagePoints) overlayBuilder;

  /// Shown under the preview — usually a note that placement is approximate.
  final String? caption;

  /// Largest height the preview may take, so it cannot push the settings off screen.
  final double maxHeight;

  const PdfEffectPreview({
    super.key,
    required this.filePath,
    required this.overlayBuilder,
    this.caption,
    this.maxHeight = 260,
  });

  @override
  State<PdfEffectPreview> createState() => _PdfEffectPreviewState();
}

class _PdfEffectPreviewState extends State<PdfEffectPreview> {
  PdfPageImage? _image;
  double _widthPt = 1;
  double _heightPt = 1;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PdfEffectPreview old) {
    super.didUpdateWidget(old);
    if (old.filePath != widget.filePath) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      final page = await doc.getPage(1);
      _widthPt = page.width;
      _heightPt = page.height;
      // Rendered a little above the display size so it stays crisp, but nowhere near the
      // page's full resolution — this is a preview, not the output.
      final image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      await doc.close();
      if (!mounted) return;
      setState(() {
        _image = image;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return SizedBox(
        height: widget.maxHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed || _image == null) {
      return SizedBox(
        height: 64,
        child: Center(
          child: Text(
            "This file can't be previewed, but the tool will still process it.",
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.maxHeight,
          child: LayoutBuilder(builder: (context, constraints) {
            // Fit the page inside the space without distorting it, so a setting expressed
            // as a fraction of the page lands where the preview says it will.
            final aspect = _widthPt / _heightPt;
            double canvasW, canvasH;
            if (constraints.maxWidth / constraints.maxHeight > aspect) {
              canvasH = constraints.maxHeight;
              canvasW = canvasH * aspect;
            } else {
              canvasW = constraints.maxWidth;
              canvasH = canvasW / aspect;
            }
            final canvas = Size(canvasW, canvasH);

            return Center(
              child: Container(
                width: canvasW,
                height: canvasH,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.surfaceRadius,
                  border: Border.all(color: theme.dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Positioned.fill(
                    child: Image.memory(_image!.bytes, fit: BoxFit.fill),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: widget.overlayBuilder(
                          context, canvas, Size(_widthPt, _heightPt)),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
        if (widget.caption != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.caption!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
