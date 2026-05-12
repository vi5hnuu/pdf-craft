import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';

/// Global BLoC observer — logs errors across all blocs.
/// Rate-app counting is handled in MainScreen via BlocListener.
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    LoggerSingleton().logger.e('BLoC error in ${bloc.runtimeType}', error: error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
