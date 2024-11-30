import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/enums/listing-type.dart';
import 'package:pdf_craft/pages/MainScreen.dart';
import 'package:pdf_craft/pages/SplashScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/FilesScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/HomeScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ScannerScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/SettingScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ToolsScreen.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/widgets/FilesListing.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _filesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'files');
final GlobalKey<NavigatorState> _toolsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tools');
final GlobalKey<NavigatorState> _scannerNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'scanner');
final GlobalKey<NavigatorState> _settingsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'settings');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black, // Change to your desired color
    systemNavigationBarIconBrightness:
        Brightness.light, // Adjust icons if needed
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
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        // The screen to display as the root in the first tab of the
        // bottom navigation bar.
        parentNavigatorKey: _rootNavigatorKey,
        path: '/file-selection',
        name: 'file-selection',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: FilesListing(
              type: ListingType.fromJson(state.uri.queryParameters['type']!)),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state,
            StatefulNavigationShell navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                // The screen to display as the root in the first tab of the
                // bottom navigation bar.
                path: '/',
                name: 'home',
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _filesNavigatorKey,
            initialLocation: '/files',
            routes: <RouteBase>[
              GoRoute(
                path: '/files',
                name: 'files',
                builder: (BuildContext context, GoRouterState state) =>
                    const FilesScreen(),
                routes: [
                  GoRoute(
                    // The screen to display as the root in the first tab of the
                    // bottom navigation bar.
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'listing',
                    name: 'listing',
                    pageBuilder: (context, state) => CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: FilesListing(
                          type: ListingType.fromJson(state.uri.queryParameters['type']!)),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  ),
                ]
              ),
            ],
          ),
          StatefulShellBranch(
              navigatorKey: _toolsNavigatorKey,
              initialLocation: '/tools',
              routes: [
                GoRoute(
                  // The screen to display as the root in the first tab of the
                  // bottom navigation bar.
                  path: '/tools',
                  name: 'tools',
                  builder: (BuildContext context, GoRouterState state) =>
                      const ToolsScreen(),
                ),
              ]),
          StatefulShellBranch(
              navigatorKey: _scannerNavigatorKey,
              initialLocation: '/scanner',
              routes: [
                GoRoute(
                  // The screen to display as the root in the first tab of the
                  // bottom navigation bar.
                  path: '/scanner',
                  name: 'scanner',
                  builder: (BuildContext context, GoRouterState state) =>
                      const ScannerScreen(),
                ),
              ]),
          StatefulShellBranch(
              navigatorKey: _settingsNavigatorKey,
              initialLocation: '/setting',
              routes: [
                GoRoute(
                  // The screen to display as the root in the first tab of the
                  // bottom navigation bar.
                  path: '/setting',
                  name: 'setting',
                  builder: (BuildContext context, GoRouterState state) =>
                      const SettingScreen(),
                ),
              ]),
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
        useMaterial3: true,
        brightness: Brightness.dark,
        // Ensures dark mode defaults
        scaffoldBackgroundColor: Colors.black,
        // Black background
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: TextTheme(
          bodySmall: TextStyle(color: Colors.white), // Primary text color
          bodyMedium: TextStyle(color: Colors.white), // Secondary text color
          bodyLarge: TextStyle(color: Colors.white), // AppBar title color
        ),
      ),
      routerConfig: _router,
    );
  }
}
