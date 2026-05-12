import 'package:dio/dio.dart';
import 'package:pdf_craft/utils/Constants.dart';

import '../../singletons/DioSingleton.dart';

class ImageApi {
  static final ImageApi _instance = ImageApi._();

  static String get _compressImage => "${Constants.baseUrl}/image-studio/compress-image";
  static String get _convertToJpg => "${Constants.baseUrl}/image-studio/convert-to-jpg";
  static String get _convertFromJpg => "${Constants.baseUrl}/image-studio/convert-from-jpg";
  static String get _resizeImage => "${Constants.baseUrl}/image-studio/resize-image";

  ImageApi._();
  factory ImageApi() {
    return _instance;
  }

  Future<Map<String, dynamic>> compressImage() async {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> convertToJpg({required String kathaId, CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> convertFromJpg({required String kathaId, CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> resizeImage({required String kathaTitle, CancelToken? cancelToken}) async {
    // var url = _vratKathaByTitle.replaceAll("{kathaTitle}", kathaTitle);
    // var res = await DioSingleton().dio.get(url, cancelToken: cancelToken);
    // return res.data;
    throw UnimplementedError();
  }
}
