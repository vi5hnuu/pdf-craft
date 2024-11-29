import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/pages/MainScreen.dart';
import 'package:pdf_craft/pages/SplashScreen.dart';
import 'package:pdf_craft/pages/tab-screens/FilesScreen.dart';
import 'package:pdf_craft/pages/tab-screens/HomeScreen.dart';
import 'package:pdf_craft/pages/tab-screens/ScannerScreen.dart';
import 'package:pdf_craft/pages/tab-screens/SettingScreen.dart';
import 'package:pdf_craft/pages/tab-screens/ToolsScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/FilesScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/HomeScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ScannerScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/SettingScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ToolsScreen.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black, // Change to your desired color
    systemNavigationBarIconBrightness: Brightness.light, // Adjust icons if needed
  ));
  runApp(NestedTabNavigationExampleApp());
}

class NestedTabNavigationExampleApp extends StatelessWidget {
  NestedTabNavigationExampleApp({super.key});

  final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    navigatorKey: _rootNavigatorKey, //navigator = 1
    initialLocation: '/splash',
    routes: [
      GoRoute(
        name: 'splash',
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                // The screen to display as the root in the first tab of the
                // bottom navigation bar.
                path: '/',
                name: 'home',
                builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/files',
            routes: <RouteBase>[
              GoRoute(
                // The screen to display as the root in the first tab of the
                // bottom navigation bar.
                path: '/files',
                name: 'files',
                builder: (BuildContext context, GoRouterState state) => const FilesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/tools',
            routes: [
              GoRoute(
                // The screen to display as the root in the first tab of the
                // bottom navigation bar.
                path: '/tools',
                name: 'tools',
                builder: (BuildContext context, GoRouterState state) => const ToolsScreen(),
              ),
            ]
          ),
          StatefulShellBranch(
              initialLocation: '/scanner',
              routes: [
                GoRoute(
                  // The screen to display as the root in the first tab of the
                  // bottom navigation bar.
                  path: '/scanner',
                  name: 'scanner',
                  builder: (BuildContext context, GoRouterState state) => const ScannerScreen(),
                ),
              ]
          ),
          StatefulShellBranch(
              initialLocation: '/setting',
              routes: [
                GoRoute(
                  // The screen to display as the root in the first tab of the
                  // bottom navigation bar.
                  path: '/setting',
                  name: 'setting',
                  builder: (BuildContext context, GoRouterState state) => const SettingScreen(),
                ),
              ]
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: NotificationService.messengerKey,
      title: 'Pdf craft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(1, 223, 81, 73)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}