import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/singletons/crash_reporter.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';

/// Global BLoC observer — logs errors across all blocs.
/// Rate-app counting is handled in MainScreen via BlocListener.
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    LoggerSingleton().logger.e('BLoC error in ${bloc.runtimeType}', error: error, stackTrace: stackTrace);
    // The bloc type is safe to disclose; the state it was holding is not.
    CrashReporter().recordNonFatal(error, stackTrace, reason: 'BLoC ${bloc.runtimeType}');
    super.onError(bloc, error, stackTrace);
  }
}
