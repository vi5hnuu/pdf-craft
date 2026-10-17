import 'package:flutter/material.dart';
import 'package:pdf_craft/theme/app_semantic_colors.dart';
import 'package:pdf_craft/widgets/pdf_page_thumbnail.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/theme/app_radius.dart';

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

  /// Accent colour for the selection highlight. Defaults to the brand primary.
  ///
  /// It used to default to [Colors.blue], and no caller ever overrode it, so every range
  /// picker in the app was blue while the brand is red.
  final Color? accent;

  const PageSelectorGrid({
    super.key,
    required this.document,
    required this.totalPages,
    required this.selected,
    required this.onToggle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? Theme.of(context).colorScheme.primary;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
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
              borderRadius: BorderRadius.circular(AppRadius.surface),
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
                    color: accentColor.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(AppRadius.surface),
                    border: Border.all(color: accentColor, width: 2),
                  ),
                ),
              ),
            // A solid badge rather than a bare glyph over the wash. A white tick on a 35%-alpha
            // accent laid over a white page thumbnail measured 1.47:1 — invisible, leaving the
            // 2px border as the only thing distinguishing a selected page. Filling the badge
            // makes the contrast independent of whatever the page happens to show, and putting
            // it in the corner stops it covering the content being chosen.
            if (isSel)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppSemanticColors.onFilled(accentColor), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.check,
                      color: AppSemanticColors.onFilled(accentColor), size: 16),
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
                    borderRadius: BorderRadius.circular(AppRadius.surface),
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
