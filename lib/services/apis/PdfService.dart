import 'package:dio/dio.dart';
import 'package:pdf_craft/constants/Constants.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/models/request/merge-pdf.dart';
import 'package:pdf_craft/models/request/page-numbers.dart';
import 'package:pdf_craft/models/request/pdf-to-jpg.dart';
import 'package:pdf_craft/models/request/protect-pdf.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/models/request/unlock-pdf.dart';

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

  Future<MultipartFile> mergePdf({required MergePdf mergePdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_mergePdf,mergePdf,cancelToken:cancelToken);
  }

  Future<MultipartFile> reorderPdf({required ReorderPdf reorderPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_reorderPdf,reorderPdf,cancelToken:cancelToken);
  }

  Future<MultipartFile> splitPdf({required SplitPdf splitPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_splitPdf,splitPdf,cancelToken:cancelToken);
  }

  Future<MultipartFile> pdfToJpg({required PdfToJpg pdfToJpg, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_pdfToJpg,pdfToJpg,cancelToken:cancelToken);
  }

  Future<MultipartFile> imageToPdf({required ImageToPdf imageToPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_imageToPdf,imageToPdf,cancelToken:cancelToken);
  }

  Future<MultipartFile> pageNumbers({required PageNumbers pageNumber, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_pageNumbers,pageNumber,cancelToken:cancelToken);
  }

  Future<MultipartFile> rotatePdf({required RotatePdf rotatePdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_rotatePdf,rotatePdf,cancelToken:cancelToken);
  }

  Future<MultipartFile> unprotectPdf({required UnlockPdf unlockOdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_unprotectPdf,unlockOdf,cancelToken:cancelToken);
  }

  Future<MultipartFile> protectpdf({required ProtectPdf protectPdf, CancelToken? cancelToken}) async {
    return await DioSingleton().dio.post(_protectpdf,protectPdf,cancelToken:cancelToken);
  }
}
