import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/pages/ErrorPage.dart';
import 'package:pdf_craft/pages/CompressPdfView.dart';
import 'package:pdf_craft/pages/CropPdfView.dart';
import 'package:pdf_craft/pages/ExtractTextView.dart';
import 'package:pdf_craft/pages/GrayscalePdfView.dart';
import 'package:pdf_craft/pages/ImageToPdfView.dart';
import 'package:pdf_craft/pages/MainScreen.dart';
import 'package:pdf_craft/pages/MergePdfView.dart';
import 'package:pdf_craft/pages/PageNumbersPdfView.dart';
import 'package:pdf_craft/pages/PdfToJpgView.dart';
import 'package:pdf_craft/pages/ProtectPdfView.dart';
import 'package:pdf_craft/pages/ReorderPdfView.dart';
import 'package:pdf_craft/pages/RotatePdfView.dart';
import 'package:pdf_craft/pages/SearchScreen.dart';
import 'package:pdf_craft/pages/SplashScreen.dart';
import 'package:pdf_craft/pages/UnProtectPdfView.dart';
import 'package:pdf_craft/pages/WatermarkPdfView.dart';
import 'package:pdf_craft/pages/split-pdf-tool/SplitPdfView.dart';
import 'package:pdf_craft/pages/tab-widgets/FilesScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/HomeScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ScannerScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/SettingScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ToolsScreen.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/apis/PdfService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/widgets/DirectoryFilesListing.dart';
import 'package:pdf_craft/widgets/FilesListing.dart';
import 'package:pdf_craft/widgets/FilesManagement.dart';
import 'package:pdf_craft/widgets/PdfPreview.dart';
import 'package:permission_handler/permission_handler.dart';

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
    initialLocation: AppRoutes.splashRoute.path,
    redirect: (context, state) async {
      final granted=await StoragePermissions.isStoragePermissionGranted();
      if(granted) return null;
      return AppRoutes.errorRoute.path;
    },
    routes: [
      GoRoute(
        name: AppRoutes.splashRoute.name,
        path: AppRoutes.splashRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: AppRoutes.errorRoute.name,
        path: AppRoutes.errorRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: Errorpage(reason: state.extra is Map<String,Object> ? ((state.extra as Map)['reason'] ?? ErrorReason.STORAGE_PERMISSION_DENIED) : ErrorReason.STORAGE_PERMISSION_DENIED,),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: AppRoutes.searchRoute.name,
        path: AppRoutes.searchRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: SearchScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        redirect: (context, state) {
          if(state.extra is! FileSelectionConfig) return AppRoutes.errorRoute.path;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.fileManagement.path,
        name: AppRoutes.fileManagement.name,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: FilesManagement(config: state.extra as FileSelectionConfig),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        // The screen to display as the root in the first tab of the
        // bottom navigation bar.
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.mergePdfRoute.path,
        name: AppRoutes.mergePdfRoute.name,
        // builder: (BuildContext context, GoRouterState state) => MergePdfView(files: state.extra as List<File>),
        builder: (BuildContext context, GoRouterState state) => MergePdfView(files: (state.extra as Map)['files'] as List<File>),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.reorderPdfPagesRoute.path,
        name: AppRoutes.reorderPdfPagesRoute.name,
        builder: (BuildContext context, GoRouterState state) => ReorderPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.pdfToJpgRoute.path,
        name: AppRoutes.pdfToJpgRoute.name,
        // builder: (BuildContext context, GoRouterState state) => MergePdfView(files: state.extra as List<File>),
        builder: (BuildContext context, GoRouterState state) => PdfToJpgView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.imageToPdfRoute.path,
        name: AppRoutes.imageToPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => ImageToPdfView(files: ((state.extra as Map)['files'] as List<File>)),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.pageNumbersRoute.path,
        name: AppRoutes.pageNumbersRoute.name,
        builder: (BuildContext context, GoRouterState state) => PageNumberPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.splitPdfRoute.path,
        name: AppRoutes.splitPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => SplitPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.protectPdfRoute.path,
        name: AppRoutes.protectPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => ProtectPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.unprotectPdfRoute.path,
        name: AppRoutes.unprotectPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => UnProtectPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.rotatePdfRoute.path,
        name: AppRoutes.rotatePdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => RotatePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.compressPdfRoute.path,
        name: AppRoutes.compressPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => CompressPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.watermarkPdfRoute.path,
        name: AppRoutes.watermarkPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => WatermarkPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.extractTextRoute.path,
        name: AppRoutes.extractTextRoute.name,
        builder: (BuildContext context, GoRouterState state) => ExtractTextView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.grayscalePdfRoute.path,
        name: AppRoutes.grayscalePdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => GrayscalePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          final files=(state.extra as Map)['files'];
          if(files is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.cropPdfRoute.path,
        name: AppRoutes.cropPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => CropPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        // The screen to display as the root in the first tab of the
        // bottom navigation bar.
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.pdfFilePreviewRoute.path,
        name: AppRoutes.pdfFilePreviewRoute.name,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: PdfPreview(pdfFilePath: state.pathParameters['pdfFilePath']!),
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
          // StatefulShellBranch(
          //   navigatorKey: _homeNavigatorKey,
          //   routes: <RouteBase>[
          //     GoRoute(
          //       // The screen to display as the root in the first tab of the
          //       // bottom navigation bar.
          //       path: AppRoutes.homeRoute.path,
          //       name: AppRoutes.homeRoute.name,
          //       builder: (BuildContext context, GoRouterState state) =>
          //           const HomeScreen(),
          //     ),
          //   ],
          // ),
          StatefulShellBranch(
            navigatorKey: _filesNavigatorKey,
            initialLocation: AppRoutes.filesRoute.path,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.filesRoute.path,
                name: AppRoutes.filesRoute.name,
                builder: (BuildContext context, GoRouterState state) => const FilesScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.filesListingRoute.path,
                    name: AppRoutes.filesListingRoute.name,
                    pageBuilder: (context, state){
                      final config=state.extra as FileSelectionConfig;
                      return CustomTransitionPage<void>(
                        key: state.pageKey,
                        child: FilesListing(config: config),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                      );
                    },
                  ),
                ]
              ),
            ],
          ),
          StatefulShellBranch(
              navigatorKey: _toolsNavigatorKey,
              initialLocation: AppRoutes.toolsRoute.path,
              routes: [
                GoRoute(
                  // The screen to display as the root in the first tab of the
                  // bottom navigation bar.
                  path: AppRoutes.toolsRoute.path,
                  name: AppRoutes.toolsRoute.name,
                  builder: (BuildContext context, GoRouterState state) =>
                      const ToolsScreen(),
                ),
              ]),
          StatefulShellBranch(
              navigatorKey: _scannerNavigatorKey,
              initialLocation: AppRoutes.scannerRoute.path,
              routes: [
                GoRoute(
                  // The screen to display as the root in the first tab of the
                  // bottom navigation bar.
                  path: AppRoutes.scannerRoute.path,
                  name: AppRoutes.scannerRoute.name,
                  builder: (BuildContext context, GoRouterState state) => ScannerScreen(),
                ),
              ]),
          // StatefulShellBranch(
          //     navigatorKey: _settingsNavigatorKey,
          //     initialLocation: AppRoutes.settingsRoute.path,
          //     routes: [
          //       GoRoute(
          //         // The screen to display as the root in the first tab of the
          //         // bottom navigation bar.
          //         path: AppRoutes.settingsRoute.path,
          //         name: AppRoutes.settingsRoute.name,
          //         builder: (BuildContext context, GoRouterState state) =>
          //             const SettingScreen(),
          //       ),
          //     ]),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(providers: [
      BlocProvider(lazy: true,create: (context) => FilesBloc()),
      BlocProvider(lazy: true,create: (context) => PdfBloc(pdfService: PdfService()))
    ], child: MaterialApp.router(
      scaffoldMessengerKey: NotificationService.messengerKey,
      title: 'Pdf craft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE53935),
          onPrimary: Colors.white,
          secondary: Color(0xFFE53935),
          onSecondary: Colors.white,
          surface: Color(0xFF1A1A1A),
          onSurface: Colors.white,
          error: Color(0xFFCF6679),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        canvasColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          iconTheme: IconThemeData(color: Colors.white),
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D0D0D),
          selectedItemColor: Color(0xFFE53935),
          unselectedItemColor: Color(0xFF888888),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        textTheme: const TextTheme(
          bodySmall: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333333))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333333))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5)),
          labelStyle: const TextStyle(color: Color(0xFF888888)),
          fillColor: const Color(0xFF1A1A1A),
          filled: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        sliderTheme: const SliderThemeData(activeTrackColor: Color(0xFFE53935), thumbColor: Color(0xFFE53935), inactiveTrackColor: Color(0xFF333333)),
        radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFFE53935) : const Color(0xFF888888))),
        checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFFE53935) : Colors.transparent), side: const BorderSide(color: Color(0xFF888888))),
        dividerColor: const Color(0xFF2A2A2A),
        cardColor: const Color(0xFF1A1A1A),
      ),
      routerConfig: _router,
    ));
  }
}
