import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/utils/FileSortFilter.dart';
import 'package:pdf_craft/widgets/FilterPill.dart';

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

  /// Translated label for a sort field (the enum's own `label` is English-only).
  static String _modeLabel(BuildContext context, FileSortMode mode) {
    final l = L10n.of(context);
    return switch (mode) {
      FileSortMode.name => l.sortName,
      FileSortMode.date => l.sortDate,
      FileSortMode.size => l.sortSize,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(L10n.of(context).sortLabel,
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 6),
        ...FileSortMode.values.map((m) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterPill(
                  label: _modeLabel(context, m),
                  selected: mode == m,
                  onTap: () => onModeChanged(m)),
            )),
        FilterPill(
          label: ascending ? L10n.of(context).sortAsc : L10n.of(context).sortDesc,
          icon: ascending ? Icons.arrow_upward : Icons.arrow_downward,
          selected: true,
          onTap: onToggleDirection,
        ),
      ],
    );
  }
}
