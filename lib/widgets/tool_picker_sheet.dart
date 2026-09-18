/// The one sheet for "which tool do you want to run on this?".
///
/// There were four of these — the selection bar, the file actions sheet, the next-tool sheet
/// after a result, and the Drive screen — each rendering a flat, unsearchable, ungrouped
/// `ListView`. With 61 tools in the registry a single PDF matches 47 of them, and three of the
/// four did not set `isScrollControlled`, so that list was capped at about half the screen. The
/// Tools tab has had search since it was written; none of the sheets used it.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/favorite_tools_service.dart';
import 'package:pdf_craft/singletons/recent_tools_service.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/utils/debouncer.dart';

class ToolPickerSheet extends StatefulWidget {
  /// The files the chosen tool will run on. Drives which tools are offered.
  final List<File> files;

  /// Shown under the title — usually the file's name, or "3 files".
  final String subtitle;

  /// Runs the chosen tool. The sheet closes first, so this is handed the caller's context.
  final void Function(ToolDef tool) onSelected;

  const ToolPickerSheet({
    super.key,
    required this.files,
    required this.subtitle,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<File> files,
    required String subtitle,
    required void Function(ToolDef tool) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      // Both matter here: the list is long enough to want the whole screen, and without
      // useSafeArea its top runs under the status bar and the display cutout.
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.surface))),
      builder: (_) => ToolPickerSheet(
        files: files,
        subtitle: subtitle,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<ToolPickerSheet> createState() => _ToolPickerSheetState();
}

class _ToolPickerSheetState extends State<ToolPickerSheet> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 200);
  String _query = '';

  /// Recently-used tool ids. Loaded once — the service reads SharedPreferences, so it cannot be
  /// consulted from build().
  List<String> _recentIds = const [];

  @override
  void initState() {
    super.initState();
    RecentToolsService().getRecentToolIds().then((ids) {
      if (mounted) setState(() => _recentIds = ids);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  /// Applicable tools, filtered by the query, with favourites and recents lifted to the top.
  ///
  /// Neither service was consulted by any of the sheets this replaces, so the tool someone uses
  /// every day sat wherever declaration order happened to put it.
  List<ToolDef> get _results {
    final applicable = ToolRegistry.toolsForSelection(widget.files);
    if (_query.trim().isEmpty) return applicable;
    final matching = ToolRegistry.search(_query, context: context).toSet();
    return applicable.where(matching.contains).toList();
  }

  /// Tools from [from] whose ids are in [ids], in the order [ids] gives them — most-recent or
  /// most-favoured first rather than registry declaration order.
  List<ToolDef> _pick(List<ToolDef> from, List<String> ids) {
    if (_query.trim().isNotEmpty) return const [];
    final byId = {for (final t in from) t.id: t};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L10n.of(context);
    final results = _results;
    final favourites = _pick(results, FavoriteToolsService().ids);
    final recent =
        _pick(results, _recentIds).where((t) => !favourites.contains(t)).toList();
    final pinned = {...favourites, ...recent};
    final rest = results.where((t) => !pinned.contains(t)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.nextToolTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              isDense: true,
              hintText: l.toolsSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _debouncer.run(() {
              if (mounted) setState(() => _query = v);
            }),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.trim().isEmpty ? l.selNoToolsApply : l.toolsNoneFound,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              : ListView(
                  controller: scrollController,
                  children: [
                    if (favourites.isNotEmpty) ...[
                      _header(theme, l.favorites),
                      ...favourites.map((t) => _tile(theme, t)),
                    ],
                    if (recent.isNotEmpty) ...[
                      _header(theme, l.toolsRecentlyUsed),
                      ...recent.map((t) => _tile(theme, t)),
                    ],
                    if (pinned.isNotEmpty) const Divider(height: 1),
                    // Grouped by category, so 47 entries read as a handful of short lists
                    // rather than one undifferentiated scroll.
                    for (final category in ToolCategories.all)
                      if (rest.any((t) => t.category == category)) ...[
                        _header(theme, category.localizedName(context)),
                        ...rest
                            .where((t) => t.category == category)
                            .map((t) => _tile(theme, t)),
                      ],
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _header(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(text,
            style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
      );

  Widget _tile(ThemeData theme, ToolDef tool) => ListTile(
        leading: Icon(tool.icon, color: tool.category.color),
        title: Text(tool.localizedName(context)),
        subtitle: Text(tool.localizedDescription(context),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () {
          Navigator.pop(context);
          widget.onSelected(tool);
        },
      );
}
