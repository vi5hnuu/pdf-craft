/// A list of every field placed on the current page.
library;

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/pages/form-editor/editor_field.dart';
import 'package:pdf_craft/pages/form-editor/form_field_type.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// Lets the author find and select a field by name instead of hunting for it on the page.
///
/// A real form runs to thirty or more fields, many of them small and overlapping the document's
/// own text; picking the right one by tapping the canvas is slow and error-prone. Reordering
/// here also sets the order a filler tabs through the finished PDF, which previously was just
/// whatever order the fields happened to be placed in.
class FieldListSheet extends StatelessWidget {
  final List<EditorField> fields;
  final String? selectedId;
  final void Function(EditorField) onSelect;
  /// Reorders a field. The callback receives the already-adjusted destination index, which is
  /// what `onReorderItem` provides (the older `onReorder` left the caller to correct for the
  /// removed item and was a common source of off-by-one bugs).
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Group colour and letter, so a row matches the badge drawn on the canvas.
  final Color Function(String group) groupColor;
  final String Function(String group) groupLetter;

  const FieldListSheet({
    super.key,
    required this.fields,
    required this.selectedId,
    required this.onSelect,
    required this.onReorder,
    required this.groupColor,
    required this.groupLetter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(L10n.of(context).fieldListTitle,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(L10n.of(context).fieldListCount(fields.length),
                style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 8),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text(L10n.of(context).fieldListEmpty,
                  style: theme.textTheme.bodyMedium)),
            )
          else
            // Capped so the sheet never grows past half the screen on a long form.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: fields.length,
                onReorderItem: onReorder,
                itemBuilder: (context, i) {
                  final f = fields[i];
                  final grouped = f.type.isGrouped && f.group.isNotEmpty;
                  final accent = grouped ? groupColor(f.group) : theme.colorScheme.primary;
                  return ListTile(
                    key: ValueKey(f.id),
                    dense: true,
                    selected: f.id == selectedId,
                    selectedTileColor: accent.withValues(alpha: 0.10),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: accent.withValues(alpha: 0.15),
                      child: Icon(f.type.icon, size: 15, color: accent),
                    ),
                    title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      grouped
                          ? '${f.type.localizedLabel(context)} · ${L10n.of(context).groupLabel} ${groupLetter(f.group)}'
                          : f.type.localizedLabel(context),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: Padding(
                        // A 48dp target: the bare handle icon was too small to grab reliably.
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.surface)),
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(f);
                    },
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}
