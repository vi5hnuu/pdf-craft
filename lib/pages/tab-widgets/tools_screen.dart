import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/favorite_tools_service.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/singletons/recent_tools_service.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/utils/debouncer.dart';
import 'package:pdf_craft/widgets/banner_add.dart';
import 'package:pdf_craft/widgets/credit_balance_chip.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/theme/app_radius.dart';

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
    final results = ToolRegistry.search(_query, context: context);

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
                        Text(L10n.of(context).toolsAllTools,
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3)),
                        const SizedBox(width: 8),
                        Text(L10n.of(context).toolsCount(ToolRegistry.tools.length),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  // Live credit balance → tap to earn/buy.
                  const CreditBalanceChip(),
                  const SizedBox(width: 4),
                  // Quick access to everything tools have produced.
                  IconButton(
                    icon: const Icon(Icons.folder_special_outlined),
                    tooltip: L10n.of(context).resultsTitle,
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
                  hintText: L10n.of(context).toolsSearchHint,
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
                      borderRadius: BorderRadius.circular(AppRadius.surface)),
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
            child: Text(L10n.of(context).toolsNoneFound,
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

/// Size of one cell in the 3-column tool grid ([_CategorySection] and search results: 16px side
/// padding, 10px spacing, 0.95 aspect ratio). The horizontal Favorites / Recently used rows use
/// the same size — they used a fixed 88px card, narrower than the grid, which clipped the
/// credit-cost badge.
Size _toolCellSize(BuildContext context) {
  const columns = 3;
  const spacing = 10.0;
  const sidePadding = 16.0;
  const aspectRatio = 0.95;
  final width =
      (MediaQuery.sizeOf(context).width - sidePadding * 2 - spacing * (columns - 1)) / columns;
  return Size(width, width / aspectRatio);
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            const Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 6),
            Text(L10n.of(context).favorites,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ),
        SizedBox(
          height: _toolCellSize(context).height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tools.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => SizedBox(
                width: _toolCellSize(context).width,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(L10n.of(context).toolsRecentlyUsed,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              // Same cell size as the grid below, so cards (and their cost badge) match exactly.
              height: _toolCellSize(context).height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tools.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => SizedBox(
                    width: _toolCellSize(context).width,
                    child: ToolCard(tool: tools[i], accentColor: tools[i].category.color)),
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
                  borderRadius: BorderRadius.circular(AppRadius.surface),
                ),
                child: Icon(category.icon, color: category.color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                category.localizedName(context),
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
    final name = tool.localizedName(context);
    final nowFav = await FavoriteToolsService().toggle(tool.id);
    NotificationService.showSnackbar(
      text: nowFav
          ? L10n.current.toolAddedToFavorites(name)
          : L10n.current.toolRemovedFromFavorites(name),
      color: nowFav ? Colors.amber : Colors.blueGrey,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFav = FavoriteToolsService().isFavorite(tool.id);
    final cost = tool.creditCost;
    // One sentence describing the whole card. Without it a screen reader announced the card as a
    // bare icon name, which said nothing about which of 61 tools the user had landed on, and then
    // read the info badge, cost badge and label as three more unexplained nodes.
    return Semantics(
      button: true,
      label: cost > 0
          ? L10n.of(context).a11yToolCard(
              tool.localizedName(context), _spokenDescription(context), cost)
          : L10n.of(context).a11yToolCardFree(
              tool.localizedName(context), _spokenDescription(context)),
      hint: isFav ? L10n.of(context).a11yFavourited : null,
      // The card now describes itself, so its decorative children are excluded rather than
      // announced one by one.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => tool.openPicker(context),
        // Long-press to pin/unpin from favourites.
        onLongPress: () => _toggleFavorite(context),
        child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.surface),
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
                    borderRadius: BorderRadius.circular(AppRadius.surface),
                  ),
                  child: Icon(tool.icon, color: accentColor, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  tool.localizedName(context),
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
            if (tool.localizedDescription(context).isNotEmpty)
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
            // Credit-cost badge (top-right) — shown for paid tools once prices load.
            Positioned(
              top: -2,
              right: -2,
              child: AnimatedBuilder(
                animation: CreditService(),
                builder: (context, _) {
                  final cost = tool.creditCost;
                  if (cost <= 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.surface),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.toll, size: 10, color: accentColor),
                        const SizedBox(width: 2),
                        Text('$cost',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor)),
                      ],
                    ),
                  );
                },
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
      ),
    );
  }

  /// The description with any trailing full stop removed.
  ///
  /// The label template supplies its own sentence breaks, so a description that already ends in
  /// a stop produced "…and more.. Free." when read aloud.
  String _spokenDescription(BuildContext context) {
    final text = tool.localizedDescription(context).trim();
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [
          Icon(tool.icon, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
              child: Text(tool.localizedName(dialogContext),
                  style: const TextStyle(fontSize: 17))),
        ]),
        content: Text(tool.localizedDescription(dialogContext),
            style: const TextStyle(height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(L10n.of(dialogContext).gotIt))],
      ),
    );
  }
}
