import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';

/// Reports crashes and non-fatal errors.
///
/// Before this the app had no reporter and no global error handler: a crash in the wild left no
/// trace, so the only way a defect surfaced was a user complaining. Every uncaught Flutter error,
/// platform error and zone error now lands here.
///
/// Deliberately quiet about content. Reports carry the account id (to tell "one user hit this a
/// hundred times" from "a hundred users hit it once") but never an email, never a file path and
/// never a request body — a PDF's filename alone can disclose what a document is.
class CrashReporter {
  static final CrashReporter _instance = CrashReporter._();
  CrashReporter._();
  factory CrashReporter() => _instance;

  bool _ready = false;

  /// True once Firebase initialised. Reporting is a no-op before that rather than an error, so a
  /// failure to reach Firebase can never take the app down with it.
  bool get isReady => _ready;

  Future<void> init() async {
    // Debug crashes belong in the console, not in the production dashboard, where they would
    // drown the real ones.
    if (kDebugMode) return;
    try {
      await Firebase.initializeApp();
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _ready = true;
    } catch (e) {
      // Never let crash reporting be the thing that crashes the app.
      LoggerSingleton().logger.w('Crash reporting unavailable: $e');
    }
  }

  /// Ties reports to an account without identifying the person.
  Future<void> setUser(String? userId) async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
  }

  /// Records something that went wrong but did not crash the app — a failed upload, a bloc
  /// error — so recurring failures are visible without a crash to trigger them.
  void recordNonFatal(Object error, StackTrace? stack, {String? reason}) {
    if (!_ready) {
      LoggerSingleton().logger.w('${reason ?? 'Error'}: $error');
      return;
    }
    FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: false);
  }

  /// Breadcrumb trail leading up to a crash. Callers must pass only what is safe to disclose:
  /// a tool id or route name, never a filename.
  void log(String message) {
    if (_ready) FirebaseCrashlytics.instance.log(message);
  }
}
