import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/theme/theme_manager.dart';

class MainScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  MainScreen({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: widget.navigationShell,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset('assets/logo.webp', fit: BoxFit.fitWidth, width: 124),
        ),
        leadingWidth: 112,
        actions: [
          ListenableBuilder(
            listenable: ThemeManager(),
            builder: (context, _) => PopupMenuButton<ThemeMode>(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Theme',
              onSelected: (mode) => ThemeManager().setMode(mode),
              itemBuilder: (context) => [
                _themeMenuItem(
                    context, ThemeMode.dark, 'Dark Mode', Icons.dark_mode),
                _themeMenuItem(
                    context, ThemeMode.light, 'Light Mode', Icons.light_mode),
                _themeMenuItem(context, ThemeMode.system, 'System Default',
                    Icons.settings_suggest),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                GoRouter.of(context).pushNamed(AppRoutes.searchRoute.name),
            icon: const Icon(Icons.search),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        iconSize: 24,
        showUnselectedLabels: true,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.folder_copy_outlined),
              label: 'Files',
              activeIcon: Icon(Icons.folder)),
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_fix_high_outlined),
              label: 'Tools',
              activeIcon: Icon(Icons.auto_fix_high)),
          BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner_outlined),
              label: 'Scanner',
              activeIcon: Icon(Icons.document_scanner)),
        ],
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }

  PopupMenuItem<ThemeMode> _themeMenuItem(
      BuildContext context, ThemeMode mode, String label, IconData icon) {
    final current = ThemeManager().mode;
    return PopupMenuItem<ThemeMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
          if (current == mode) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
    );
  }

  void _onTap(int index) {
    widget.navigationShell
        .goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
  }
}
