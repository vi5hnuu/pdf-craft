import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/FavoriteToolsService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/singletons/RecentToolsService.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/utils/Debouncer.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';

/// Tools tab. Reads the data-driven [ToolRegistry] (single source of truth) and
/// adds tool search + a "Recently used" shortcut row.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 200);
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Warm the favourites cache so cards can render their star synchronously.
    FavoriteToolsService().load();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = _query.trim().isNotEmpty;
    final results = ToolRegistry.search(_query);

    // Rebuild on favourite changes so stars and the favourites row stay live.
    return AnimatedBuilder(
      animation: FavoriteToolsService(),
      builder: (context, _) => SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text('All Tools',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3)),
                        const SizedBox(width: 8),
                        Text('( ${ToolRegistry.tools.length} )',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  // Quick access to everything tools have produced.
                  IconButton(
                    icon: const Icon(Icons.folder_special_outlined),
                    tooltip: 'Results',
                    onPressed: () =>
                        GoRouter.of(context).pushNamed(AppRoutes.resultsRoute.name),
                  ),
                ],
              ),
            ),
          ),
          // Search box.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search tools',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searching
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _debouncer.cancel();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => _debouncer.run(() {
                  if (mounted) setState(() => _query = v);
                }),
              ),
            ),
          ),

          if (searching)
            // Flat search results grid.
            _buildToolsGrid(theme, results)
          else ...[
            // Pinned favourites row (hidden when none).
            SliverToBoxAdapter(child: _FavoriteToolsRow()),
            // Recently used row (live via RecentToolsService).
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: RecentToolsService(),
                builder: (context, _) => _RecentToolsRow(),
              ),
            ),
            // Category sections.
            for (int i = 0; i < ToolCategories.all.length; i++) ...[
              SliverToBoxAdapter(
                child: _CategorySection(category: ToolCategories.all[i]),
              ),
              if ((i + 1) % 2 == 0)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: BannerAdd(),
                  ),
                ),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      ),
    );
  }

  // Sliver grid of tool cards (used for search results).
  Widget _buildToolsGrid(ThemeData theme, List<ToolDef> tools) {
    if (tools.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text('No tools found',
                style: TextStyle(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => ToolCard(
              tool: tools[i], accentColor: tools[i].category.color),
          childCount: tools.length,
        ),
      ),
    );
  }
}

/// Horizontal row of the user's pinned favourite tools (hidden when empty).
/// Toggle a favourite by long-pressing any tool card.
class _FavoriteToolsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tools = FavoriteToolsService()
        .ids
        .map(ToolRegistry.byId)
        .whereType<ToolDef>()
        .toList(growable: false);
    if (tools.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Icon(Icons.star, size: 16, color: Colors.amber),
            SizedBox(width: 6),
            Text('Favourites',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tools.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SizedBox(
                width: 88,
                child: ToolCard(tool: tools[i], accentColor: tools[i].category.color)),
          ),
        ),
      ],
    );
  }
}

/// Horizontal row of the user's recently used tools (hidden when empty).
class _RecentToolsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: RecentToolsService().getRecentToolIds(),
      builder: (context, snapshot) {
        final ids = snapshot.data ?? const [];
        final tools = ids
            .map(ToolRegistry.byId)
            .whereType<ToolDef>()
            .toList(growable: false);
        if (tools.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Recently used',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              // Tall enough for ToolCard's icon box + 2-line label + padding
              // (otherwise the card overflows the row vertically).
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tools.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    SizedBox(width: 88, child: ToolCard(tool: tools[i], accentColor: tools[i].category.color)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final ToolCategory category;

  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    final tools = ToolRegistry.byCategory(category);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(category.icon, color: category.color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                category.name,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: category.color,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: tools
                .map((tool) =>
                    ToolCard(tool: tool, accentColor: category.color))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// A single tappable tool card. Launches the tool's file-picker flow.
class ToolCard extends StatelessWidget {
  final ToolDef tool;
  final Color accentColor;

  const ToolCard({super.key, required this.tool, required this.accentColor});

  Future<void> _toggleFavorite(BuildContext context) async {
    final nowFav = await FavoriteToolsService().toggle(tool.id);
    NotificationService.showSnackbar(
      text: nowFav ? '${tool.name} added to favourites' : '${tool.name} removed from favourites',
      color: nowFav ? Colors.amber : Colors.blueGrey,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFav = FavoriteToolsService().isFavorite(tool.id);
    return GestureDetector(
      onTap: () => tool.openPicker(context),
      // Long-press to pin/unpin from favourites.
      onLongPress: () => _toggleFavorite(context),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          // Center the icon+label block; the star badge is separately positioned.
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tool.icon, color: accentColor, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  tool.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      height: 1.3),
                ),
              ],
            ),
            // Info affordance (top-left) — reveals what the tool does.
            if (tool.description.isNotEmpty)
              Positioned(
                top: -2,
                left: -2,
                child: GestureDetector(
                  onTap: () => _showInfo(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.info_outline, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                  ),
                ),
              ),
            // Ad hint (top-right) for tools that require watching an ad. Hint only.
            if (tool.isHeavy)
              Positioned(
                top: 0,
                right: 0,
                child: Tooltip(
                  message: 'Requires watching a short ad',
                  child: Icon(Icons.smart_display_outlined, size: 15, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                ),
              ),
            if (isFav)
              const Positioned(
                bottom: 0,
                right: 0,
                child: Icon(Icons.star, size: 14, color: Colors.amber),
              ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(tool.icon, color: accentColor),
          const SizedBox(width: 10),
          Expanded(child: Text(tool.name, style: const TextStyle(fontSize: 17))),
        ]),
        content: Text(tool.description, style: const TextStyle(height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
      ),
    );
  }
}
