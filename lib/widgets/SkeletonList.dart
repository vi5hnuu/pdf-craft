import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmering placeholder list shown while file lists load, instead of a bare
/// spinner. Each row mimics a [FileTile] (thumbnail block + two text lines) so
/// the transition to real content is calm rather than a jarring pop-in.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  const SkeletonList({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        // Don't let the placeholder scroll independently of the real list.
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _box(44, 44, 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(double.infinity, 12, 4),
                    const SizedBox(height: 8),
                    _box(120, 10, 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(double w, double h, double r) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
        ),
      );
}
