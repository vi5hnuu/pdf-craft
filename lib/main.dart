
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/pages/SplashScreen.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

final parentNavKey=GlobalKey<NavigatorState>();

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static final _whiteListedRoutes = [];
  final router=GoRouter(
      debugLogDiagnostics: true,
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
      ]);

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);//lifecycycle events
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      key: parentNavKey,
      scaffoldMessengerKey: NotificationService.messengerKey,
      title: 'Code Sprout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.greenAccent),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
  }
}
