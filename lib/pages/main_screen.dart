import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/rate_app_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/locale_manager.dart';
import 'package:pdf_craft/utils/responsive.dart';
import 'package:pdf_craft/widgets/app_logo.dart';

class MainScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// One tab, described once so the bottom bar and the rail cannot drift apart.
class _Destination {
  final IconData icon;
  final IconData activeIcon;
  final String Function(BuildContext) label;

  const _Destination(this.icon, this.activeIcon, this.label);
}

const _destinations = <_Destination>[
  _Destination(Icons.folder_copy_outlined, Icons.folder, _filesLabel),
  _Destination(Icons.auto_fix_high_outlined, Icons.auto_fix_high, _toolsLabel),
  _Destination(Icons.document_scanner_outlined, Icons.document_scanner, _scannerLabel),
  _Destination(Icons.cloud_outlined, Icons.cloud, _cloudLabel),
];

// Tear-offs rather than closures, so _destinations can stay const.
String _filesLabel(BuildContext c) => L10n.of(c).navFiles;
String _toolsLabel(BuildContext c) => L10n.of(c).navTools;
String _scannerLabel(BuildContext c) => L10n.of(c).navScanner;
String _cloudLabel(BuildContext c) => L10n.of(c).navCloud;

class _MainScreenState extends State<MainScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<PdfBloc, PdfState>(
      // Fire when any httpState key newly transitions to done
      listenWhen: (prev, curr) => curr.httpStates.entries.any(
        (e) => e.value.done == true && prev.httpStates[e.key]?.done != true,
      ),
      // Google's own review flow decides whether to show anything, so there is no dialog of
      // ours to open and nothing to keep a context alive for.
      listener: (context, state) => RateAppService().recordSuccess(),
      child: Scaffold(
      // A rail once there is width for it; the bottom bar would otherwise spend scarce
      // landscape height and sit a long way from where the hands rest on a tablet.
      // MediaQuery here, not LayoutBuilder: this decision is about the window.
      body: _usesRail(context)
          ? Row(children: [
              _rail(context),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: widget.navigationShell),
            ])
          : widget.navigationShell,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: AppLogo(width: 112, fit: BoxFit.fitWidth),
        ),
        leadingWidth: 112,
        actions: [
          // Quick language switch: English ⇄ हिन्दी.
          //
          // The glyph alone — a bare "हि" or "EN" — was the whole control, sitting between two
          // icon buttons. It had no affordance: nothing said it was a language switch rather
          // than a stray character, and to a reader who does not know Devanagari "हि" is not
          // even legible as a word.
          //
          // A globe rather than the translate glyph: this is a PDF tool, and a translate icon
          // in its app bar reads as an offer to translate the *document*. The globe is the
          // conventional mark for the app's own locale. The target language stays beside it so
          // the tap's outcome is still visible, spelled "हिं" — "हि" on its own is half a
          // syllable, which is why it looked like a broken character.
          ListenableBuilder(
            listenable: LocaleManager(),
            builder: (context, _) => Tooltip(
              message: L10n.of(context).switchLanguageTooltip,
              child: TextButton.icon(
                onPressed: () => LocaleManager().toggleEnglishHindi(),
                icon: const Icon(Icons.language, size: 20),
                label: Text(
                  LocaleManager().isHindi ? 'EN' : 'हिं',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: L10n.of(context).actionSearch,
            onPressed: () =>
                GoRouter.of(context).pushNamed(AppRoutes.searchRoute.name),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: L10n.of(context).actionSettings,
            onPressed: () =>
                GoRouter.of(context).pushNamed(AppRoutes.settingsRoute.name),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
      ),
      bottomNavigationBar: _usesRail(context)
          ? null
          : BottomNavigationBar(
              iconSize: 24,
              showUnselectedLabels: true,
              items: [
                for (final d in _destinations)
                  BottomNavigationBarItem(
                    icon: Icon(d.icon),
                    activeIcon: Icon(d.activeIcon),
                    label: d.label(context),
                  ),
              ],
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onTap,
            ),
    ),
    );
  }

  static bool _usesRail(BuildContext context) =>
      windowSizeFor(MediaQuery.sizeOf(context).width).atLeast(WindowSize.medium);

  Widget _rail(BuildContext context) {
    // Labels only once there is room: at medium width a labelled rail would claim a third of it.
    final size = windowSizeFor(MediaQuery.sizeOf(context).width);
    return NavigationRail(
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: _onTap,
      labelType: size == WindowSize.expanded
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.selected,
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.activeIcon),
            label: Text(d.label(context)),
          ),
      ],
    );
  }


  void _onTap(int index) {
    widget.navigationShell
        .goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
  }
}
