import 'package:flutter/material.dart';
import 'package:pdf_craft/utils/FileSortFilter.dart';

/// Shared sort-field pills + ascending/descending toggle, used by the Files
/// browser and Search so sorting looks and behaves identically in both.
class SortControls extends StatelessWidget {
  final FileSortMode mode;
  final bool ascending;
  final ValueChanged<FileSortMode> onModeChanged;
  final VoidCallback onToggleDirection;

  const SortControls({
    super.key,
    required this.mode,
    required this.ascending,
    required this.onModeChanged,
    required this.onToggleDirection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sort:',
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 4),
        ...FileSortMode.values.map((m) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _pill(theme, primary,
                  label: m.label,
                  selected: mode == m,
                  onTap: () => onModeChanged(m)),
            )),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onToggleDirection,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _pill(ThemeData theme, Color primary,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? primary : theme.dividerColor, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected
                ? primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
