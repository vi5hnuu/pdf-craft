import 'package:flutter/material.dart';
import 'package:pdf_craft/state/selection/SelectionService.dart';
import 'package:pdf_craft/tools/tool_registry.dart';

/// Bottom action bar shown while a cross-folder selection is active. Lets the
/// user review/clear the selection and apply an applicable tool. Shared by the
/// Files browser and Search so multi-select behaves identically in both.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = SelectionService().count;
    return Material(
      elevation: 8,
      color: theme.cardColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('$count selected',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: 'Manage selection',
                icon: const Icon(Icons.checklist),
                onPressed: () => showManageSelections(context),
              ),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () => SelectionService().clear(),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => showToolsForSelection(context),
                icon: const Icon(Icons.build, size: 18),
                label: const Text('Tools'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Intellisense menu: shows only the tools that apply to the current selection
/// (single-file tools for one file, multi-file tools once their minimum is met,
/// extension filters honored) — driven by [ToolRegistry].
void showToolsForSelection(BuildContext context) {
  final files = SelectionService().files;
  final applicable = ToolRegistry.toolsForSelection(files);
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => SafeArea(
      child: applicable.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tools apply to this selection'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Apply to ${files.length} file(s)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: applicable
                        .map((tool) => ListTile(
                              leading:
                                  Icon(tool.icon, color: tool.category.color),
                              title: Text(tool.name),
                              onTap: () {
                                Navigator.pop(context);
                                final selected = SelectionService().files;
                                SelectionService().clear();
                                tool.openWithFiles(context, selected);
                              },
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
    ),
  );
}

/// Lets the user review the cross-folder selection and remove individual items
/// (or clear all).
void showManageSelections(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => SafeArea(
      child: AnimatedBuilder(
        animation: SelectionService(),
        builder: (ctx, _) {
          final files = SelectionService().files;
          if (files.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No files selected'),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text('${files.length} selected',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => SelectionService().clear(),
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (c, i) {
                    final f = files[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(f.path.split('/').last,
                          overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => SelectionService().removeByPath(f.path),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
