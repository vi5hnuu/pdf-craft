import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/tools/tool_registry.dart';

/// Offers the tools that can be applied to a file the user is already looking at.
///
/// Finishing a tool used to be a dead end: the result was saved, and running a second tool on it
/// meant leaving the screen, opening the file browser and finding the output again by name. The
/// registry already knows which tools accept which file types, and [ToolDef.openWithFiles] already
/// launches one with a file in hand — this just puts that within reach of the result itself.
class NextToolSheet extends StatelessWidget {
  final File file;

  const NextToolSheet({super.key, required this.file});

  /// Presents the sheet. Does nothing if no tool accepts this file.
  static Future<void> show(BuildContext context, File file) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NextToolSheet(file: file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = ToolRegistry.toolsForSelection([file]);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Use this file in another tool',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        file.path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (tools.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No other tool accepts this kind of file.',
                  style: theme.textTheme.bodyMedium),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tools.length,
                itemBuilder: (context, index) {
                  final tool = tools[index];
                  return ListTile(
                    leading: Icon(tool.icon, color: tool.category.color),
                    title: Text(tool.name),
                    subtitle: Text(tool.category.name),
                    onTap: () {
                      Navigator.pop(context);
                      tool.openWithFiles(context, [file]);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
