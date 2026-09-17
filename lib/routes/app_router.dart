/// The app's route table.
///
/// Lifted out of `main.dart`, which had grown to 1,099 lines with 79 routes buried in the middle
/// of app bootstrap. Keeping navigation here leaves `main.dart` to do one job — start the app —
/// and makes a route easy to find by name.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/file_selection_config.dart';
import 'package:pdf_craft/pages/add_blank_pages_view.dart';
import 'package:pdf_craft/pages/edit_metadata_view.dart';
import 'package:pdf_craft/pages/error_page.dart';
import 'package:pdf_craft/pages/flatten_pdf_view.dart';
import 'package:pdf_craft/pages/compress_pdf_view.dart';
import 'package:pdf_craft/pages/crop_pdf_view.dart';
import 'package:pdf_craft/pages/extract_text_view.dart';
import 'package:pdf_craft/pages/grayscale_pdf_view.dart';
import 'package:pdf_craft/pages/header_footer_view.dart';
import 'package:pdf_craft/pages/image_to_pdf_view.dart';
import 'package:pdf_craft/pages/main_screen.dart';
import 'package:pdf_craft/pages/merge_pdf_view.dart';
import 'package:pdf_craft/pages/page_numbers_pdf_view.dart';
import 'package:pdf_craft/pages/pdf_info_view.dart';
import 'package:pdf_craft/pages/pdf_to_jpg_view.dart';
import 'package:pdf_craft/pages/protect_pdf_view.dart';
import 'package:pdf_craft/pages/repair_pdf_view.dart';
import 'package:pdf_craft/pages/reorder_pdf_view.dart';
import 'package:pdf_craft/pages/rotate_pdf_view.dart';
import 'package:pdf_craft/pages/search_screen.dart';
import 'package:pdf_craft/pages/recents_screen.dart';
import 'package:pdf_craft/pages/credits_screen.dart';
import 'package:pdf_craft/pages/auth_screen.dart';
import 'package:pdf_craft/pages/account_screen.dart';
import 'package:pdf_craft/pages/results_screen.dart';
import 'package:pdf_craft/pages/organize_pages_view.dart';
import 'package:pdf_craft/pages/extract_pages_view.dart';
import 'package:pdf_craft/pages/delete_pages_view.dart';
import 'package:pdf_craft/pages/remove_metadata_view.dart';
import 'package:pdf_craft/pages/extract_images_view.dart';
import 'package:pdf_craft/pages/sanitize_pdf_view.dart';
import 'package:pdf_craft/pages/split_by_size_view.dart';
import 'package:pdf_craft/pages/reverse_pages_view.dart';
import 'package:pdf_craft/pages/mirror_pages_view.dart';
import 'package:pdf_craft/pages/resize_page_view.dart';
import 'package:pdf_craft/pages/scale_pdf_view.dart';
import 'package:pdf_craft/pages/insert_pdf_view.dart';
import 'package:pdf_craft/pages/extract_embedded_files_view.dart';
import 'package:pdf_craft/pages/analyze_pdf_view.dart';
import 'package:pdf_craft/pages/replace_pages_view.dart';
import 'package:pdf_craft/pages/extract_fonts_view.dart';
import 'package:pdf_craft/pages/rotate_image_view.dart';
import 'package:pdf_craft/pages/flip_image_view.dart';
import 'package:pdf_craft/pages/add_border_view.dart';
import 'package:pdf_craft/pages/incoming_files_screen.dart';
import 'package:pdf_craft/pages/batch_process_view.dart';
import 'package:pdf_craft/pages/onboarding_screen.dart';
import 'package:pdf_craft/pages/splash_screen.dart';
import 'package:pdf_craft/pages/stamp_pdf_view.dart';
import 'package:pdf_craft/pages/qr_stamp_pdf_view.dart';
import 'package:pdf_craft/pages/annotate_pdf_view.dart';
import 'package:pdf_craft/pages/form_editor_view.dart';
import 'package:pdf_craft/pages/place_image_view.dart';
import 'package:pdf_craft/pages/image_studio_view.dart';
import 'package:pdf_craft/pages/pdf_to_office_view.dart';
import 'package:pdf_craft/pages/drive_screen.dart';
import 'package:pdf_craft/pages/redact_pdf_view.dart';
import 'package:pdf_craft/pages/duplicate_pages_view.dart';
import 'package:pdf_craft/pages/bookmarks_editor_view.dart';
import 'package:pdf_craft/pages/pdf_compare_view.dart';
import 'package:pdf_craft/pages/sign_pdf_view.dart';
import 'package:pdf_craft/pages/remove_blank_pages_view.dart';
import 'package:pdf_craft/pages/optimize_pdf_view.dart';
import 'package:pdf_craft/pages/n_up_pdf_view.dart';
import 'package:pdf_craft/models/request/image_studio.dart' show ImageStudioOp;
import 'package:pdf_craft/models/request/pdf_to_office.dart' show PdfOfficeFormat;
import 'package:pdf_craft/pages/un_protect_pdf_view.dart';
import 'package:pdf_craft/pages/watermark_pdf_view.dart';
import 'package:pdf_craft/pages/split-pdf-tool/split_pdf_view.dart';
import 'package:pdf_craft/pages/tab-widgets/files_screen.dart';
import 'package:pdf_craft/pages/tab-widgets/scanner_screen.dart';
import 'package:pdf_craft/pages/tab-widgets/setting_screen.dart';
import 'package:pdf_craft/pages/tab-widgets/tools_screen.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/utils/storage_permissions.dart';
import 'package:pdf_craft/widgets/files_listing.dart';
import 'package:pdf_craft/widgets/files_management.dart';
import 'package:pdf_craft/widgets/pdf_preview.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> filesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'files');
final GlobalKey<NavigatorState> toolsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tools');
final GlobalKey<NavigatorState> scannerNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'scanner');
final GlobalKey<NavigatorState> cloudNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'cloud');

  /// Route guard: a tool route is only valid when the caller actually passed files.
///
/// Reaching a tool screen without them (a stale deep link, a restored back stack) used to throw
/// inside the page; this redirects to the error route instead.
String? _requireFiles(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  if (extra is! Map || extra['files'] is! List<File>) return AppRoutes.errorRoute.path;
  return null;
}

final GoRouter appRouter = GoRouter(
    debugLogDiagnostics: true,
    navigatorKey: rootNavigatorKey, //navigator = 1
    initialLocation: AppRoutes.splashRoute.path,
    redirect: (context, state) async {
      // Splash, onboarding and the permission page itself never need storage access. Gating
      // them sent brand-new users to the permission wall before they had seen the intro (and
      // skipped the splash's ad initialisation).
      final path = state.matchedLocation;
      if (path == AppRoutes.splashRoute.path ||
          path == AppRoutes.onboardingRoute.path ||
          path == AppRoutes.errorRoute.path) {
        return null;
      }
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
        parentNavigatorKey: rootNavigatorKey,
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
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.errorRoute.name,
        path: AppRoutes.errorRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: Errorpage(reason: state.extra is Map<String,Object> ? ((state.extra as Map)['reason'] ?? ErrorReason.storagePermissionDenied) : ErrorReason.storagePermissionDenied,),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.searchRoute.name,
        path: AppRoutes.searchRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SearchScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.creditsRoute.name,
        path: AppRoutes.creditsRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const CreditsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.authRoute.name,
        path: AppRoutes.authRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: AuthScreen(
              initialCreateMode: state.uri.queryParameters['mode'] != 'signin'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.accountRoute.name,
        path: AppRoutes.accountRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const AccountScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.recentsRoute.name,
        path: AppRoutes.recentsRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RecentsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.resultsRoute.name,
        path: AppRoutes.resultsRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const ResultsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.settingsRoute.name,
        path: AppRoutes.settingsRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SettingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        name: AppRoutes.incomingFilesRoute.name,
        path: AppRoutes.incomingFilesRoute.path,
        redirect: (context, state) =>
            state.extra is List<File> ? null : AppRoutes.errorRoute.path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: IncomingFilesScreen(files: state.extra as List<File>),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        redirect: (context, state) {
          if(state.extra is! FileSelectionConfig) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: rootNavigatorKey,
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
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.mergePdfRoute.path,
        name: AppRoutes.mergePdfRoute.name,
        // builder: (BuildContext context, GoRouterState state) => MergePdfView(files: state.extra as List<File>),
        builder: (BuildContext context, GoRouterState state) => MergePdfView(files: (state.extra as Map)['files'] as List<File>),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.reorderPdfPagesRoute.path,
        name: AppRoutes.reorderPdfPagesRoute.name,
        builder: (BuildContext context, GoRouterState state) => ReorderPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfToJpgRoute.path,
        name: AppRoutes.pdfToJpgRoute.name,
        // builder: (BuildContext context, GoRouterState state) => MergePdfView(files: state.extra as List<File>),
        builder: (BuildContext context, GoRouterState state) => PdfToJpgView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.imageToPdfRoute.path,
        name: AppRoutes.imageToPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => ImageToPdfView(files: ((state.extra as Map)['files'] as List<File>)),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pageNumbersRoute.path,
        name: AppRoutes.pageNumbersRoute.name,
        builder: (BuildContext context, GoRouterState state) => PageNumberPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.splitPdfRoute.path,
        name: AppRoutes.splitPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => SplitPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.protectPdfRoute.path,
        name: AppRoutes.protectPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => ProtectPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.unprotectPdfRoute.path,
        name: AppRoutes.unprotectPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => UnProtectPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.rotatePdfRoute.path,
        name: AppRoutes.rotatePdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => RotatePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.compressPdfRoute.path,
        name: AppRoutes.compressPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => CompressPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.watermarkPdfRoute.path,
        name: AppRoutes.watermarkPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => WatermarkPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.extractTextRoute.path,
        name: AppRoutes.extractTextRoute.name,
        builder: (BuildContext context, GoRouterState state) => ExtractTextView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.grayscalePdfRoute.path,
        name: AppRoutes.grayscalePdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => GrayscalePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.cropPdfRoute.path,
        name: AppRoutes.cropPdfRoute.name,
        builder: (BuildContext context, GoRouterState state) => CropPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfInfoRoute.path,
        name: AppRoutes.pdfInfoRoute.name,
        builder: (context, state) => PdfInfoView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.editMetadataRoute.path,
        name: AppRoutes.editMetadataRoute.name,
        builder: (context, state) => EditMetadataView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.headerFooterRoute.path,
        name: AppRoutes.headerFooterRoute.name,
        builder: (context, state) => HeaderFooterView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.repairPdfRoute.path,
        name: AppRoutes.repairPdfRoute.name,
        builder: (context, state) => RepairPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.flattenPdfRoute.path,
        name: AppRoutes.flattenPdfRoute.name,
        builder: (context, state) => FlattenPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.addBlankPagesRoute.path,
        name: AppRoutes.addBlankPagesRoute.name,
        builder: (context, state) => AddBlankPagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.stampPdfRoute.path,
        name: AppRoutes.stampPdfRoute.name,
        builder: (context, state) => StampPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.qrStampPdfRoute.path,
        name: AppRoutes.qrStampPdfRoute.name,
        builder: (context, state) =>
            QrStampPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.annotatePdfRoute.path,
        name: AppRoutes.annotatePdfRoute.name,
        builder: (context, state) =>
            AnnotatePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.formPdfRoute.path,
        name: AppRoutes.formPdfRoute.name,
        builder: (context, state) =>
            FormEditorView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Used by QR Stamp: extra is { 'file': File, 'imageBytes': Uint8List, 'title': String }
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.placeImageRoute.path,
        name: AppRoutes.placeImageRoute.name,
        builder: (context, state) {
          final extra = state.extra as Map;
          return PlaceImageView(
            pdfFile: extra['file'] as File,
            preloadedImageBytes: extra['imageBytes'] as Uint8List?,
            title: extra['title'] as String? ?? L10n.of(context).placeImage,
          );
        },
      ),
      // Used by Image Overlay tool: extra comes from fileManagement with 'files' key
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.imageOverlayRoute.path,
        name: AppRoutes.imageOverlayRoute.name,
        builder: (context, state) => PlaceImageView(
          pdfFile: ((state.extra as Map)['files'] as List<File>).first,
          title: L10n.of(context).imageOverlayTitle,
        ),
      ),
      // Image Studio: extra has 'files' list + 'op' ImageStudioOp
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
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
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfToWordRoute.path,
        name: AppRoutes.pdfToWordRoute.name,
        builder: (context, state) => PdfToOfficeView(
          file: ((state.extra as Map)['files'] as List<File>).first,
          format: PdfOfficeFormat.word,
        ),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfToExcelRoute.path,
        name: AppRoutes.pdfToExcelRoute.name,
        builder: (context, state) => PdfToOfficeView(
          file: ((state.extra as Map)['files'] as List<File>).first,
          format: PdfOfficeFormat.excel,
        ),
      ),
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfToPptxRoute.path,
        name: AppRoutes.pdfToPptxRoute.name,
        builder: (context, state) => PdfToOfficeView(
          file: ((state.extra as Map)['files'] as List<File>).first,
          format: PdfOfficeFormat.pptx,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.batchProcessRoute.path,
        name: AppRoutes.batchProcessRoute.name,
        builder: (context, state) {
          final files = (state.extra as Map)['files'] as List<File>;
          return BatchProcessView(files: files);
        },
      ),
      // Sign PDF — single file; draws signature then navigates to PlaceImageView
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.signPdfRoute.path,
        name: AppRoutes.signPdfRoute.name,
        builder: (context, state) => SignPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Remove blank pages
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.removeBlankPagesRoute.path,
        name: AppRoutes.removeBlankPagesRoute.name,
        builder: (context, state) => RemoveBlankPagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Optimize PDF
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.optimizePdfRoute.path,
        name: AppRoutes.optimizePdfRoute.name,
        builder: (context, state) => OptimizePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // N-Up PDF layout
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.nUpPdfRoute.path,
        name: AppRoutes.nUpPdfRoute.name,
        builder: (context, state) => NUpPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Redact PDF — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.redactPdfRoute.path,
        name: AppRoutes.redactPdfRoute.name,
        builder: (context, state) => RedactPdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Duplicate Pages — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.duplicatePagesRoute.path,
        name: AppRoutes.duplicatePagesRoute.name,
        builder: (context, state) => DuplicatePagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Bookmarks Editor — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.bookmarksEditorRoute.path,
        name: AppRoutes.bookmarksEditorRoute.name,
        builder: (context, state) => BookmarksEditorView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Organize Pages — single file (visual reorder + delete)
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.organizePagesRoute.path,
        name: AppRoutes.organizePagesRoute.name,
        builder: (context, state) => OrganizePagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Extract Pages — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.extractPagesRoute.path,
        name: AppRoutes.extractPagesRoute.name,
        builder: (context, state) => ExtractPagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Delete Pages — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.deletePagesRoute.path,
        name: AppRoutes.deletePagesRoute.name,
        builder: (context, state) => DeletePagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Remove Metadata — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.removeMetadataRoute.path,
        name: AppRoutes.removeMetadataRoute.name,
        builder: (context, state) => RemoveMetadataView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Extract Images — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.extractImagesRoute.path,
        name: AppRoutes.extractImagesRoute.name,
        builder: (context, state) => ExtractImagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Sanitize PDF — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.sanitizePdfRoute.path,
        name: AppRoutes.sanitizePdfRoute.name,
        builder: (context, state) => SanitizePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Split by Size — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.splitBySizeRoute.path,
        name: AppRoutes.splitBySizeRoute.name,
        builder: (context, state) => SplitBySizeView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Reverse Page Order — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.reversePagesRoute.path,
        name: AppRoutes.reversePagesRoute.name,
        builder: (context, state) => ReversePagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Mirror Pages — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.mirrorPagesRoute.path,
        name: AppRoutes.mirrorPagesRoute.name,
        builder: (context, state) => MirrorPagesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Resize Page Size — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.resizePageRoute.path,
        name: AppRoutes.resizePageRoute.name,
        builder: (context, state) => ResizePageView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Scale PDF — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.scalePdfRoute.path,
        name: AppRoutes.scalePdfRoute.name,
        builder: (context, state) => ScalePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Insert PDF into PDF — two files
      GoRoute(
        redirect: (context, state) {
          final files = (state.extra as Map?)?['files'];
          if (files is! List<File> || files.length < 2) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.insertPdfRoute.path,
        name: AppRoutes.insertPdfRoute.name,
        builder: (context, state) => InsertPdfView(files: (state.extra as Map)['files'] as List<File>),
      ),
      // Extract Embedded Files — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.extractEmbeddedRoute.path,
        name: AppRoutes.extractEmbeddedRoute.name,
        builder: (context, state) => ExtractEmbeddedFilesView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Analyze PDF — single file (JSON report)
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.analyzePdfRoute.path,
        name: AppRoutes.analyzePdfRoute.name,
        builder: (context, state) => AnalyzePdfView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Replace Pages — two files
      GoRoute(
        redirect: (context, state) {
          final files = (state.extra as Map?)?['files'];
          if (files is! List<File> || files.length < 2) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.replacePagesRoute.path,
        name: AppRoutes.replacePagesRoute.name,
        builder: (context, state) => ReplacePagesView(files: (state.extra as Map)['files'] as List<File>),
      ),
      // Extract Fonts — single file
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.extractFontsRoute.path,
        name: AppRoutes.extractFontsRoute.name,
        builder: (context, state) => ExtractFontsView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Rotate Image — single image
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.rotateImageRoute.path,
        name: AppRoutes.rotateImageRoute.name,
        builder: (context, state) => RotateImageView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Flip Image — single image
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.flipImageRoute.path,
        name: AppRoutes.flipImageRoute.name,
        builder: (context, state) => FlipImageView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // Add Border — single image
      GoRoute(
        redirect: _requireFiles,
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.addBorderRoute.path,
        name: AppRoutes.addBorderRoute.name,
        builder: (context, state) => AddBorderView(file: ((state.extra as Map)['files'] as List<File>).first),
      ),
      // PDF Compare — two files via multiSelect; extra has {'files': [file1, file2]}
      GoRoute(
        redirect: (context, state) {
          final files = (state.extra as Map?)?.containsKey('files') == true
              ? (state.extra as Map)['files'] as List<File>?
              : null;
          if (files == null || files.length < 2) return AppRoutes.errorRoute.path;
          return null;
        },
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.pdfCompareRoute.path,
        name: AppRoutes.pdfCompareRoute.name,
        builder: (context, state) {
          final files = ((state.extra as Map)['files'] as List<File>);
          return PdfCompareView(file1: files[0], file2: files[1]);
        },
      ),
      // Google Drive screen — extra may be {'file': File} for direct upload, or null for browse
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
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
        parentNavigatorKey: rootNavigatorKey,
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
        parentNavigatorKey: rootNavigatorKey,
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
            navigatorKey: filesNavigatorKey,
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
              navigatorKey: toolsNavigatorKey,
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
              navigatorKey: scannerNavigatorKey,
              initialLocation: AppRoutes.scannerRoute.path,
              routes: [
                GoRoute(
                  path: AppRoutes.scannerRoute.path,
                  name: AppRoutes.scannerRoute.name,
                  builder: (BuildContext context, GoRouterState state) => const ScannerScreen(),
                ),
              ]),
          StatefulShellBranch(
              navigatorKey: cloudNavigatorKey,
              initialLocation: AppRoutes.cloudRoute.path,
              routes: [
                GoRoute(
                  path: AppRoutes.cloudRoute.path,
                  name: AppRoutes.cloudRoute.name,
                  builder: (BuildContext context, GoRouterState state) =>
                      const DriveScreen(fileToUpload: null),
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
