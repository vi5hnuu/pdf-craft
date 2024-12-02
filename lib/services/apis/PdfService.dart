import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/models/request/merge-pdf.dart';
import 'package:pdf_craft/models/request/page-numbers.dart';
import 'package:pdf_craft/models/request/pdf-to-jpg.dart';
import 'package:pdf_craft/models/request/protect-pdf.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/models/request/unlock-pdf.dart';
import 'package:pdf_craft/utils/Constants.dart';

import '../../singletons/DioSingleton.dart';

class PdfService {
  static final PdfService _instance = PdfService._();

  static const String _mergePdf = "${Constants.baseUrl}/pdf-studio/merge-pdf"; //POST
  static const String _reorderPdf = "${Constants.baseUrl}/pdf-studio/reorder-pdf"; //POST
  static const String _splitPdf = "${Constants.baseUrl}/pdf-studio/split-pdf"; //POST
  static const String _pdfToJpg = "${Constants.baseUrl}/pdf-studio/pdf-to-jpg"; //POST
  static const String _imageToPdf = "${Constants.baseUrl}/pdf-studio/image-to-pdf"; //POST
  static const String _pageNumbers = "${Constants.baseUrl}/pdf-studio/page-numbers"; //POST
  static const String _rotatePdf = "${Constants.baseUrl}/pdf-studio/rotate-pdf"; //POST
  static const String _unprotectPdf = "${Constants.baseUrl}/pdf-studio/unprotect-pdf"; //POST
  static const String _protectpdf = "${Constants.baseUrl}/pdf-studio/protect-pdf"; //POST

  PdfService._();
  factory PdfService() {
    return _instance;
  }

  Future<Response<Uint8List>> mergePdf({required MergePdf mergePdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_mergePdf,data:FormData.fromMap(mergePdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> reorderPdf({required ReorderPdf reorderPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_reorderPdf,data:FormData.fromMap(reorderPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> splitPdf({required SplitPdf splitPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_splitPdf,data:FormData.fromMap(splitPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
  }

  Future<Response<Uint8List>> pdfToJpg({required PdfToJpg pdfToJpg, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_pdfToJpg,data:FormData.fromMap(pdfToJpg.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken);
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
}
