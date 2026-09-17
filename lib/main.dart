import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/singletons/crash_reporter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/l10n/locale_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes/app_router.dart';
import 'package:pdf_craft/theme/app_theme.dart';
import 'package:pdf_craft/theme/theme_manager.dart';
import 'package:pdf_craft/services/incoming_files_channel.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/singletons/app_open_ad_manager.dart';
import 'package:pdf_craft/singletons/full_screen_ad_policy.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/singletons/pro_service.dart';
import 'package:pdf_craft/singletons/auth_service.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/singletons/purchase_service.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';


/// Redirect guard for tool routes: ensures `state.extra` carries a `files`
/// `List<File>`. Returns the error route instead of throwing on a bad cast
/// (e.g. a malformed deep link or a route restored with no extra).

Future<void> main() async {
  // runZonedGuarded catches async errors that escape every other handler — the class of failure
  // that previously vanished without trace because nothing was listening.
  runZonedGuarded(_bootstrap, (error, stack) {
    CrashReporter().recordNonFatal(error, stack, reason: 'Uncaught zone error');
    LoggerSingleton().logger.e('Uncaught: $error', error: error, stackTrace: stack);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything else, so a failure during start-up is itself reported.
  await CrashReporter().init();
  await ThemeManager().init();
  await LocaleManager().init(); // saved language (System / English / Hindi) before first frame
  await ProService().load(); // load ad-free/Pro entitlement before first frame
  // Establish an auth session (guest on first launch) in the background. This used to be
  // awaited here, so a slow or unreachable auth server held the first frame until the 20s
  // connect timeout (measured on a release build: first frame at +20.4s). Requests don't need
  // it to finish first — the Dio interceptor calls ensureSession(), which waits for it.
  unawaited(AuthService().bootstrap().catchError((Object e) {
    LoggerSingleton().logger.w('Auth bootstrap deferred: $e');
  }));
  // Load credits in the background so a slow/unreachable server never blocks the first frame.
  unawaited(CreditService().load());
  // Start the IAP lifecycle app-wide: recovers unfinished purchases and processes any
  // purchase that completes while the credits screen isn't open.
  unawaited(PurchaseService().init());
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const NestedTabNavigationExampleApp());
}

class NestedTabNavigationExampleApp extends StatefulWidget {
  const NestedTabNavigationExampleApp({super.key});

  @override
  State<NestedTabNavigationExampleApp> createState() =>
      _NestedTabNavigationExampleAppState();
}

class _NestedTabNavigationExampleAppState
    extends State<NestedTabNavigationExampleApp> with WidgetsBindingObserver {

  // Subscription to files shared into the app while it is running.
  StreamSubscription<List<String>>? _sharingSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSharingIntent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharingSub?.cancel();
    super.dispose();
  }

  /// Listens for files opened/shared into the app (Android "Open with" / share
  /// sheet) both at cold start and while running, and routes them to the
  /// incoming-files chooser.
  void _initSharingIntent() {
    _sharingSub = IncomingFilesChannel.instance.stream.listen(
      _handleSharedFiles,
      onError: (e) =>
          LoggerSingleton().logger.w('Incoming files stream error: $e'),
    );
    // Handle the file(s) that launched the app from a cold start.
    IncomingFilesChannel.instance.getInitialFiles().then(_handleSharedFiles);
  }

  void _handleSharedFiles(List<String> paths) {
    if (paths.isEmpty) return;
    final files = paths.map((p) => File(p)).toList();
    // Defer until after the current frame so the router is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.pushNamed(AppRoutes.incomingFilesRoute.name, extra: files);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      // Only a real trip to the background counts. `inactive`/`hidden` also fire for the
      // notification shade, permission dialogs and system pickers — treating those as a
      // resume showed a full-screen ad every time the user pulled down the shade.
      case AppLifecycleState.paused:
        FullScreenAdPolicy().onPaused();
        break;
      case AppLifecycleState.resumed:
        // The policy enforces minimum background time, cooldown, external flows and Pro.
        if (FullScreenAdPolicy().consumeResumeForAppOpen()) {
          AppOpenAdManager().showAdIfAvailable();
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(providers: [
      BlocProvider(lazy: true,create: (context) => FilesBloc()),
      BlocProvider(lazy: true,create: (context) => PdfBloc(pdfService: PdfService()))
    ],
      // Listen to ThemeManager HERE (around MaterialApp itself) so a theme
      // change rebuilds MaterialApp and re-reads themeMode live. Previously the
      // ListenableBuilder wrapped a const widget at runApp(), so notifications
      // could not propagate and the theme only applied on a fresh start.
      // LocaleManager is listened to alongside it so switching language rebuilds the whole app
      // live (strings, Hindi-capable font) without a restart.
      child: ListenableBuilder(
        listenable: Listenable.merge([ThemeManager(), LocaleManager()]),
        builder: (context, _) => MaterialApp.router(
          scaffoldMessengerKey: NotificationService.messengerKey,
          title: 'PDF Craft',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeManager().mode,
          theme: AppTheme.light(hindi: LocaleManager().isHindi),
          darkTheme: AppTheme.dark(hindi: LocaleManager().isHindi),
          // null locale = follow the device language.
          locale: LocaleManager().locale,
          supportedLocales: LocaleManager.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: appRouter,
          // Surface a "session expired" prompt (sign in again / continue as guest)
          // over whatever screen is showing.
          builder: (context, child) =>
              _SessionExpiryGate(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Watches [AuthService] and, when a signed-in account's session expires (the app has
/// fallen back to a guest), prompts the user to sign in again or continue as a guest.
class _SessionExpiryGate extends StatefulWidget {
  final Widget child;
  const _SessionExpiryGate({required this.child});

  @override
  State<_SessionExpiryGate> createState() => _SessionExpiryGateState();
}

class _SessionExpiryGateState extends State<_SessionExpiryGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthService().sessionExpired && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptSessionExpired());
    }
  }

  Future<void> _promptSessionExpired() async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) {
      _showing = false;
      return;
    }
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        icon: const Icon(Icons.lock_clock_outlined, size: 40),
        title: Text(L10n.of(dctx).sessionExpiredTitle),
        content: Text(L10n.of(dctx).sessionExpiredBody),
        actions: [
          TextButton(
            onPressed: () {
              AuthService().acknowledgeSessionExpired();
              Navigator.of(dctx).pop();
            },
            child: Text(L10n.of(dctx).sessionContinueGuest),
          ),
          FilledButton(
            onPressed: () {
              AuthService().acknowledgeSessionExpired();
              Navigator.of(dctx).pop();
              GoRouter.of(ctx).pushNamed(AppRoutes.authRoute.name,
                  queryParameters: {'mode': 'signin'});
            },
            child: Text(L10n.of(dctx).sessionSignInAgain),
          ),
        ],
      ),
    );
    _showing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
