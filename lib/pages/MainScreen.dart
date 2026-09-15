import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/RateAppService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/l10n/LocaleManager.dart';
import 'package:pdf_craft/widgets/AppLogo.dart';

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

    return BlocListener<PdfBloc, PdfState>(
      // Fire when any httpState key newly transitions to done
      listenWhen: (prev, curr) => curr.httpStates.entries.any(
        (e) => e.value.done == true && prev.httpStates[e.key]?.done != true,
      ),
      listener: (context, state) async {
        final should = await RateAppService().recordSuccess();
        // The dialog is opened on the listener's own context, so that is what has to still be
        // mounted; the State's `mounted` says nothing about it.
        if (should && context.mounted) _showRateDialog(context);
      },
      child: Scaffold(
      body: widget.navigationShell,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: AppLogo(width: 112, fit: BoxFit.fitWidth),
        ),
        leadingWidth: 112,
        actions: [
          // Quick language switch: English ⇄ हिन्दी. It replaces the theme menu that used to sit
          // here, which only duplicated Settings → Appearance. The label shows the language the
          // tap switches *to*.
          ListenableBuilder(
            listenable: LocaleManager(),
            builder: (context, _) => Tooltip(
              message: L10n.of(context).switchLanguageTooltip,
              child: TextButton(
                onPressed: () => LocaleManager().toggleEnglishHindi(),
                child: Text(
                  LocaleManager().isHindi ? 'EN' : 'हि',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () =>
                GoRouter.of(context).pushNamed(AppRoutes.searchRoute.name),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Settings',
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
          BottomNavigationBarItem(
              icon: Icon(Icons.cloud_outlined),
              label: 'Cloud',
              activeIcon: Icon(Icons.cloud)),
        ],
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
      ),
    ),
    );
  }

  void _showRateDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Enjoying PDF Craft?'),
        content: const Text(
          'You\'ve processed several files! If you find this app useful, please take a moment to rate it — it helps a lot.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // "Later" asks again after more uses; it used to opt the user out permanently.
              RateAppService().snooze();
              Navigator.pop(ctx);
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              await RateAppService().markRated();
              await RateAppService().openPlayStore();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _onTap(int index) {
    widget.navigationShell
        .goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
  }
}
