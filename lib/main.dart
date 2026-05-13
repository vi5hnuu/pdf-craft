import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/file-selection-config.dart';
import 'package:pdf_craft/theme/app_theme.dart';
import 'package:pdf_craft/theme/theme_manager.dart';
import 'package:pdf_craft/pages/AddBlankPagesView.dart';
import 'package:pdf_craft/pages/EditMetadataView.dart';
import 'package:pdf_craft/pages/ErrorPage.dart';
import 'package:pdf_craft/pages/FlattenPdfView.dart';
import 'package:pdf_craft/pages/CompressPdfView.dart';
import 'package:pdf_craft/pages/CropPdfView.dart';
import 'package:pdf_craft/pages/ExtractTextView.dart';
import 'package:pdf_craft/pages/GrayscalePdfView.dart';
import 'package:pdf_craft/pages/HeaderFooterView.dart';
import 'package:pdf_craft/pages/ImageToPdfView.dart';
import 'package:pdf_craft/pages/MainScreen.dart';
import 'package:pdf_craft/pages/MergePdfView.dart';
import 'package:pdf_craft/pages/PageNumbersPdfView.dart';
import 'package:pdf_craft/pages/PdfInfoView.dart';
import 'package:pdf_craft/pages/PdfToJpgView.dart';
import 'package:pdf_craft/pages/ProtectPdfView.dart';
import 'package:pdf_craft/pages/RepairPdfView.dart';
import 'package:pdf_craft/pages/ReorderPdfView.dart';
import 'package:pdf_craft/pages/RotatePdfView.dart';
import 'package:pdf_craft/pages/SearchScreen.dart';
import 'package:pdf_craft/pages/BatchProcessView.dart';
import 'package:pdf_craft/pages/OnboardingScreen.dart';
import 'package:pdf_craft/pages/SplashScreen.dart';
import 'package:pdf_craft/pages/StampPdfView.dart';
import 'package:pdf_craft/pages/QrStampPdfView.dart';
import 'package:pdf_craft/pages/AnnotatePdfView.dart';
import 'package:pdf_craft/pages/FormPdfView.dart';
import 'package:pdf_craft/pages/PlaceImageView.dart';
import 'package:pdf_craft/pages/ImageStudioView.dart';
import 'package:pdf_craft/pages/PdfToOfficeView.dart';
import 'package:pdf_craft/pages/DriveScreen.dart';
import 'package:pdf_craft/models/request/image-studio.dart' show ImageStudioOp;
import 'package:pdf_craft/models/request/pdf-to-office.dart' show PdfOfficeFormat;
import 'package:pdf_craft/pages/UnProtectPdfView.dart';
import 'package:pdf_craft/pages/WatermarkPdfView.dart';
import 'package:pdf_craft/pages/split-pdf-tool/SplitPdfView.dart';
import 'package:pdf_craft/pages/tab-widgets/FilesScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ScannerScreen.dart';
import 'package:pdf_craft/pages/tab-widgets/ToolsScreen.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/apis/PdfService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/widgets/FilesListing.dart';
import 'package:pdf_craft/widgets/FilesManagement.dart';
import 'package:pdf_craft/widgets/PdfPreview.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _filesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'files');
final GlobalKey<NavigatorState> _toolsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tools');
final GlobalKey<NavigatorState> _scannerNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'scanner');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager().init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(ListenableBuilder(
    listenable: ThemeManager(),
    builder: (context, _) => NestedTabNavigationExampleApp(),
  ));
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
        name: AppRoutes.onboardingRoute.name,
        path: AppRoutes.onboardingRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const OnboardingScreen(),
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
          return null;
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
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.pdfInfoRoute.path,
        name: AppRoutes.pdfInfoRoute.name,
        builder: (context, state) => PdfInfoView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.editMetadataRoute.path,
        name: AppRoutes.editMetadataRoute.name,
        builder: (context, state) => EditMetadataView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.headerFooterRoute.path,
        name: AppRoutes.headerFooterRoute.name,
        builder: (context, state) => HeaderFooterView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.repairPdfRoute.path,
        name: AppRoutes.repairPdfRoute.name,
        builder: (context, state) => RepairPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.flattenPdfRoute.path,
        name: AppRoutes.flattenPdfRoute.name,
        builder: (context, state) => FlattenPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.addBlankPagesRoute.path,
        name: AppRoutes.addBlankPagesRoute.name,
        builder: (context, state) => AddBlankPagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.stampPdfRoute.path,
        name: AppRoutes.stampPdfRoute.name,
        builder: (context, state) => StampPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.qrStampPdfRoute.path,
        name: AppRoutes.qrStampPdfRoute.name,
        builder: (context, state) =>
            QrStampPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.annotatePdfRoute.path,
        name: AppRoutes.annotatePdfRoute.name,
        builder: (context, state) =>
            AnnotatePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.formPdfRoute.path,
        name: AppRoutes.formPdfRoute.name,
        builder: (context, state) =>
            FormPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Used by QR Stamp: extra is { 'file': File, 'imageBytes': Uint8List, 'title': String }
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.placeImageRoute.path,
        name: AppRoutes.placeImageRoute.name,
        builder: (context, state) {
          final extra = state.extra as Map;
          return PlaceImageView(
            pdfFile: extra['file'] as File,
            preloadedImageBytes: extra['imageBytes'] as Uint8List?,
            title: extra['title'] as String? ?? 'Place Image',
          );
        },
      ),
      // Used by Image Overlay tool: extra comes from fileManagement with 'files' key
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.imageOverlayRoute.path,
        name: AppRoutes.imageOverlayRoute.name,
        builder: (context, state) => PlaceImageView(
          pdfFile: ((state.extra as Map)['files'] as List<File>).first,
          title: 'Image Overlay',
        ),
      ),
      // Image Studio: extra has 'files' list + 'op' ImageStudioOp
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.imageStudioRoute.path,
        name: AppRoutes.imageStudioRoute.name,
        builder: (context, state) {
          final extra = state.extra as Map;
          return ImageStudioView(
            file: (extra['files'] as List<File>).first,
            op: extra['op'] as ImageStudioOp? ?? ImageStudioOp.compress,
          );
        },
      ),
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.pdfToWordRoute.path,
        name: AppRoutes.pdfToWordRoute.name,
        builder: (context, state) => PdfToOfficeView(
          file: ((state.extra as Map)['files'] as List<File>).first,
          format: PdfOfficeFormat.word,
        ),
      ),
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.pdfToExcelRoute.path,
        name: AppRoutes.pdfToExcelRoute.name,
        builder: (context, state) => PdfToOfficeView(
          file: ((state.extra as Map)['files'] as List<File>).first,
          format: PdfOfficeFormat.excel,
        ),
      ),
      GoRoute(
        redirect: (context, state) {
          if ((state.extra as Map)['files'] is! List<File>) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.pdfToPptxRoute.path,
        name: AppRoutes.pdfToPptxRoute.name,
        builder: (context, state) => PdfToOfficeView(
          file: ((state.extra as Map)['files'] as List<File>).first,
          format: PdfOfficeFormat.pptx,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.batchProcessRoute.path,
        name: AppRoutes.batchProcessRoute.name,
        builder: (context, state) {
          final files = (state.extra as Map)['files'] as List<File>;
          return BatchProcessView(files: files);
        },
      ),
      // Google Drive screen — extra may be {'file': File} for direct upload, or null for browse
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.driveRoute.path,
        name: AppRoutes.driveRoute.name,
        builder: (context, state) {
          final file = (state.extra as Map?)?.containsKey('file') == true
              ? (state.extra as Map)['file'] as File?
              : null;
          return DriveScreen(fileToUpload: file);
        },
      ),
      GoRoute(
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
      themeMode: ThemeManager().mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
    ));
  }
}
