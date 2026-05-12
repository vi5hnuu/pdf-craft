import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/request/compress-pdf.dart';
import 'package:pdf_craft/models/request/crop-pdf.dart';
import 'package:pdf_craft/models/request/extract-text.dart';
import 'package:pdf_craft/models/request/grayscale-pdf.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/models/request/merge-pdf.dart';
import 'package:pdf_craft/models/request/page-numbers.dart';
import 'package:pdf_craft/models/request/pdf-to-jpg.dart';
import 'package:pdf_craft/models/request/protect-pdf.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/models/request/unlock-pdf.dart';
import 'package:pdf_craft/models/request/watermark-pdf.dart';
import 'package:pdf_craft/utils/Constants.dart';

import '../../singletons/DioSingleton.dart';

class PdfService {
  static final PdfService _instance = PdfService._();

  static const String _mergePdf = "${Constants.baseUrl}/pdf-studio/merge-pdf";
  static const String _reorderPdf = "${Constants.baseUrl}/pdf-studio/reorder-pdf";
  static const String _splitPdf = "${Constants.baseUrl}/pdf-studio/split-pdf";
  static const String _pdfToJpg = "${Constants.baseUrl}/pdf-studio/pdf-to-jpg";
  static const String _imageToPdf = "${Constants.baseUrl}/pdf-studio/image-to-pdf";
  static const String _pageNumbers = "${Constants.baseUrl}/pdf-studio/page-numbers";
  static const String _rotatePdf = "${Constants.baseUrl}/pdf-studio/rotate-pdf";
  static const String _unprotectPdf = "${Constants.baseUrl}/pdf-studio/unprotect-pdf";
  static const String _protectpdf = "${Constants.baseUrl}/pdf-studio/protect-pdf";
  static const String _compressPdf = "${Constants.baseUrl}/pdf-studio/compress-pdf";
  static const String _watermarkPdf = "${Constants.baseUrl}/pdf-studio/watermark-pdf";
  static const String _extractText = "${Constants.baseUrl}/pdf-studio/extract-text";
  static const String _grayscalePdf = "${Constants.baseUrl}/pdf-studio/grayscale-pdf";
  static const String _cropPdf = "${Constants.baseUrl}/pdf-studio/crop-pdf";

  PdfService._();
  factory PdfService() {
    return _instance;
  }

  Future<Response<Uint8List>> mergePdf({required MergePdf mergePdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_mergePdf,data:FormData.fromMap(mergePdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> reorderPdf({required ReorderPdf reorderPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_reorderPdf,data:FormData.fromMap(reorderPdf.toJson()),options: Options( contentType: 'multipart/form-data', responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> splitPdf({required SplitPdf splitPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_splitPdf,data:FormData.fromMap(splitPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> pdfToJpg({required PdfToJpg pdfToJpg, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_pdfToJpg,data:FormData.fromMap(pdfToJpg.toJson()),options: Options(contentType: 'multipart/form-data',responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> imageToPdf({required ImageToPdf imageToPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_imageToPdf,data:FormData.fromMap(imageToPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> pageNumbers({required PageNumbers pageNumber, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_pageNumbers,data:FormData.fromMap(pageNumber.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> rotatePdf({required RotatePdf rotatePdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_rotatePdf,data:FormData.fromMap(rotatePdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> unprotectPdf({required UnProtectPdf unlockOdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_unprotectPdf,data:FormData.fromMap(unlockOdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> protectpdf({required ProtectPdf protectPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_protectpdf,data:FormData.fromMap(protectPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> compressPdf({required CompressPdf compressPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_compressPdf,data:FormData.fromMap(compressPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> watermarkPdf({required WatermarkPdf watermarkPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_watermarkPdf,data:FormData.fromMap(watermarkPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> extractText({required ExtractText extractText, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_extractText,data:FormData.fromMap(extractText.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> grayscalePdf({required GrayscalePdf grayscalePdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_grayscalePdf,data:FormData.fromMap(grayscalePdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> cropPdf({required CropPdf cropPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_cropPdf,data:FormData.fromMap(cropPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }
}
