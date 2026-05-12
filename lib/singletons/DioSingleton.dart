import 'package:dio/dio.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/utils/NetworkUtils.dart';

class DioSingleton {
  final Dio dio = Dio();
  static final DioSingleton _instance = DioSingleton._();

  DioSingleton._() {
    dio.interceptors.add(
        InterceptorsWrapper(onRequest: (options, handler) async {
          // Reject immediately if device has no internet — avoids confusing timeout errors
          if (!await NetworkUtils.isOnline()) {
            return handler.reject(DioException(
              requestOptions: options,
              message: 'No internet connection. Please check your network.',
              type: DioExceptionType.connectionError,
            ));
          }
          LoggerSingleton().logger.i('REQUEST [${options.method}] => PATH: ${options.path}');
          return handler.next(options);
        },
            onResponse: (response, handler) async {
              LoggerSingleton().logger.i('RESPONSE [${response.statusCode}] => PATH: ${response.requestOptions.path}');
              return handler.next(response);
            },
            onError: (DioException e, handler) {
              LoggerSingleton().logger.e('ERROR [${e.response?.statusCode}] => PATH: ${e.requestOptions.path}', error: e.error);
              return handler.next(e);
            }));
  }

  factory DioSingleton() {
    return _instance;
  }
}
