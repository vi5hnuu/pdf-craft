import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/pages/HomeScreen.dart';
import 'package:pdf_craft/pages/SplashScreen.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _sectionANavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sectionANav');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _sectionANavigatorKey,
            initialLocation: '/a',
            routes: <RouteBase>[
              GoRoute(
                // The screen to display as the root in the first tab of the
                // bottom navigation bar.
                path: '/a',
                name: 'a',
                builder: (BuildContext context, GoRouterState state) =>
                const RootScreen(label: 'A', detailsPath: '/a/details'),
                routes: <RouteBase>[
                  // The details screen to display stacked on navigator of the
                  // first tab. This will cover screen A but not the application
                  // shell (bottom navigation bar).
                  GoRoute(
                    path: 'details',
                    name: 'details',
                    builder: (BuildContext context, GoRouterState state) =>
                    const DetailsScreen(label: 'A'),
                  ),
                ],
              ),
            ],
            // To enable preloading of the initial locations of branches, pass
            // 'true' for the parameter `preload` (false is default).
          ),
          StatefulShellBranch(
            // It's not necessary to provide a navigatorKey if it isn't also
            // needed elsewhere. If not provided, a default key will be used.
            routes: <RouteBase>[
              GoRoute(
                // The screen to display as the root in the second tab of the
                // bottom navigation bar.
                path: '/b',
                builder: (BuildContext context, GoRouterState state) =>
                const RootScreen(
                  label: 'B',
                  detailsPath: '/b/details/1',
                  secondDetailsPath: '/b/details/2',
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'details/:param',
                    builder: (BuildContext context, GoRouterState state) =>
                        DetailsScreen(
                          label: 'B',
                          param: state.pathParameters['param'],
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                // The screen to display as the root in the third tab of the
                // bottom navigation bar.
                path: '/c',
                builder: (BuildContext context, GoRouterState state) =>
                const RootScreen(
                  label: 'C',
                  detailsPath: '/c/details',
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'details',
                    builder: (BuildContext context, GoRouterState state) =>
                        DetailsScreen(
                          label: 'C',
                          extra: state.extra,
                        ),
                  ),
                ],
              ),
            ],
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

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  /// The navigation shell and container for the branch Navigators.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Section A'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Section B'),
          BottomNavigationBarItem(icon: Icon(Icons.tab), label: 'Section C'),
        ],
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
  void _onTap(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }
}

class RootScreen extends StatelessWidget {
  /// Creates a RootScreen
  const RootScreen({
    required this.label,
    required this.detailsPath,
    this.secondDetailsPath,
    super.key,
  });

  /// The label
  final String label;

  /// The path to the detail page
  final String detailsPath;

  /// The path to another detail page
  final String? secondDetailsPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Root of section $label'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Screen $label',
                style: Theme.of(context).textTheme.titleLarge),
            const Padding(padding: EdgeInsets.all(4)),
            TextButton(
              onPressed: () {
                GoRouter.of(context).go(detailsPath, extra: '$label-XYZ');
              },
              child: const Text('View details'),
            ),
            const Padding(padding: EdgeInsets.all(4)),
            if (secondDetailsPath != null)
              TextButton(
                onPressed: () {
                  GoRouter.of(context).go(secondDetailsPath!);
                },
                child: const Text('View more details'),
              ),
          ],
        ),
      ),
    );
  }
}

/// The details screen for either the A or B screen.
class DetailsScreen extends StatefulWidget {
  /// Constructs a [DetailsScreen].
  const DetailsScreen({
    required this.label,
    this.param,
    this.extra,
    this.withScaffold = true,
    super.key,
  });

  /// The label to display in the center of the screen.
  final String label;

  /// Optional param
  final String? param;

  /// Optional extra object
  final Object? extra;

  /// Wrap in scaffold
  final bool withScaffold;

  @override
  State<StatefulWidget> createState() => DetailsScreenState();
}

/// The state for DetailsScreen
class DetailsScreenState extends State<DetailsScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.withScaffold) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Details Screen - ${widget.label}'),
        ),
        body: _build(context),
      );
    } else {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _build(context),
      );
    }
  }

  Widget _build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Details for ${widget.label} - Counter: $_counter',
              style: Theme.of(context).textTheme.titleLarge),
          const Padding(padding: EdgeInsets.all(4)),
          TextButton(
            onPressed: () {
              GoRouter.of(context).pushNamed('splash');
            },
            child: const Text('splash'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _counter++;
              });
            },
            child: const Text('Increment counter'),
          ),
          const Padding(padding: EdgeInsets.all(8)),
          if (widget.param != null)
            Text('Parameter: ${widget.param!}',
                style: Theme.of(context).textTheme.titleMedium),
          const Padding(padding: EdgeInsets.all(8)),
          if (widget.extra != null)
            Text('Extra: ${widget.extra!}',
                style: Theme.of(context).textTheme.titleMedium),
          if (!widget.withScaffold) ...<Widget>[
            const Padding(padding: EdgeInsets.all(16)),
            TextButton(
              onPressed: () {
                GoRouter.of(context).pop();
              },
              child: const Text('< Back',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ]
        ],
      ),
    );
  }
}
