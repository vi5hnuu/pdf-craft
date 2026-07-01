import 'package:flutter/material.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

/// A reusable thumbnail grid for multi-selecting pages of a [PdfDocument].
///
/// Selection state is owned by the parent (passed in [selected]); this widget
/// just renders and reports taps via [onToggle]. Uses the cached
/// [PdfPageThumbnail] so scrolling and selection changes never re-render pages.
class PageSelectorGrid extends StatelessWidget {
  final PdfDocument document;
  final int totalPages;

  /// 0-indexed selected pages.
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  /// Accent color for the selection highlight.
  final Color accent;

  const PageSelectorGrid({
    super.key,
    required this.document,
    required this.totalPages,
    required this.selected,
    required this.onToggle,
    this.accent = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: totalPages,
      itemBuilder: (context, i) {
        final isSel = selected.contains(i);
        return GestureDetector(
          onTap: () => onToggle(i),
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PdfPageThumbnail(
                key: ValueKey('sel_thumb_$i'),
                document: document,
                pageNumber: i + 1,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            if (isSel)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 30),
                  ),
                ),
              ),
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
