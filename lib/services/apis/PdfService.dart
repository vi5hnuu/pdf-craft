import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/request/add-blank-pages.dart';
import 'package:pdf_craft/models/request/compress-pdf.dart';
import 'package:pdf_craft/models/request/crop-pdf.dart';
import 'package:pdf_craft/models/request/edit-metadata.dart';
import 'package:pdf_craft/models/request/extract-text.dart';
import 'package:pdf_craft/models/request/flatten-pdf.dart';
import 'package:pdf_craft/models/request/get-metadata.dart';
import 'package:pdf_craft/models/request/grayscale-pdf.dart';
import 'package:pdf_craft/models/request/header-footer.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/models/request/merge-pdf.dart';
import 'package:pdf_craft/models/request/page-numbers.dart';
import 'package:pdf_craft/models/request/pdf-to-jpg.dart';
import 'package:pdf_craft/models/request/protect-pdf.dart';
import 'package:pdf_craft/models/request/repair-pdf.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/models/request/stamp-pdf.dart';
import 'package:pdf_craft/models/request/place-image.dart';
import 'package:pdf_craft/models/request/image-studio.dart';
import 'package:pdf_craft/models/request/pdf-to-office.dart';
import 'package:pdf_craft/models/request/unlock-pdf.dart';
import 'package:pdf_craft/models/request/watermark-pdf.dart';
import 'package:pdf_craft/models/request/redact-pdf.dart';
import 'package:pdf_craft/models/request/duplicate-pages.dart';
import 'package:pdf_craft/models/request/get-bookmarks.dart';
import 'package:pdf_craft/models/request/edit-bookmarks.dart';
import 'package:pdf_craft/models/request/create-form.dart';
import 'package:pdf_craft/models/request/remove-metadata.dart';
import 'package:pdf_craft/models/request/extract-images.dart';
import 'package:pdf_craft/models/request/sanitize-pdf.dart';
import 'package:pdf_craft/models/request/split-by-size.dart';
import 'package:pdf_craft/models/request/mirror-pdf.dart';
import 'package:pdf_craft/models/request/resize-page.dart';
import 'package:pdf_craft/models/request/scale-pdf.dart';
import 'package:pdf_craft/models/request/insert-pdf.dart';
import 'package:pdf_craft/models/request/extract-embedded-files.dart';
import 'package:pdf_craft/models/request/analyze-pdf.dart';
import 'package:pdf_craft/models/request/replace-pages.dart';
import 'package:pdf_craft/models/request/extract-fonts.dart';
import 'package:pdf_craft/models/request/rotate-image.dart';
import 'package:pdf_craft/models/request/flip-image.dart';
import 'package:pdf_craft/models/request/border-image.dart';
import 'package:pdf_craft/models/request/filter-image.dart';
import 'package:pdf_craft/models/request/remove-blank-pages.dart';
import 'package:pdf_craft/models/request/optimize-pdf.dart';
import 'package:pdf_craft/models/request/n-up.dart';
import 'package:pdf_craft/utils/Constants.dart';

import '../../singletons/DioSingleton.dart';

class PdfService {
  static final PdfService _instance = PdfService._();

  static String get _redactPdf => "${Constants.baseUrl}/pdf-studio/redact-pdf";
  static String get _duplicatePages => "${Constants.baseUrl}/pdf-studio/duplicate-pages";
  static String get _getBookmarks => "${Constants.baseUrl}/pdf-studio/get-bookmarks";
  static String get _createForm => "${Constants.baseUrl}/pdf-studio/create-form";
  static String get _removeMetadata => "${Constants.baseUrl}/pdf-studio/remove-metadata";
  static String get _extractImages => "${Constants.baseUrl}/pdf-studio/extract-images";
  static String get _sanitizePdf => "${Constants.baseUrl}/pdf-studio/sanitize-pdf";
  static String get _splitBySize => "${Constants.baseUrl}/pdf-studio/split-by-size";
  static String get _mirrorPdf => "${Constants.baseUrl}/pdf-studio/mirror-pdf";
  static String get _resizePage => "${Constants.baseUrl}/pdf-studio/resize-page";
  static String get _scalePdf => "${Constants.baseUrl}/pdf-studio/scale-pdf";
  static String get _insertPdf => "${Constants.baseUrl}/pdf-studio/insert-pdf";
  static String get _extractEmbedded => "${Constants.baseUrl}/pdf-studio/extract-embedded-files";
  static String get _analyzePdf => "${Constants.baseUrl}/pdf-studio/analyze-pdf";
  static String get _replacePages => "${Constants.baseUrl}/pdf-studio/replace-pages";
  static String get _extractFonts => "${Constants.baseUrl}/pdf-studio/extract-fonts";
  static String get _editBookmarks => "${Constants.baseUrl}/pdf-studio/edit-bookmarks";
  static String get _filterImage => "${Constants.baseUrl}/image-studio/filter-image";
  static String get _removeBlankPages => "${Constants.baseUrl}/pdf-studio/remove-blank-pages";
  static String get _optimizePdf => "${Constants.baseUrl}/pdf-studio/optimize-pdf";
  static String get _nUpPdf => "${Constants.baseUrl}/pdf-studio/n-up";
  static String get _getMetadata => "${Constants.baseUrl}/pdf-studio/get-metadata";
  static String get _editMetadata => "${Constants.baseUrl}/pdf-studio/edit-metadata";
  static String get _headerFooter => "${Constants.baseUrl}/pdf-studio/header-footer";
  static String get _repairPdf => "${Constants.baseUrl}/pdf-studio/repair-pdf";
  static String get _flattenPdf => "${Constants.baseUrl}/pdf-studio/flatten-pdf";
  static String get _addBlankPages => "${Constants.baseUrl}/pdf-studio/add-blank-pages";
  static String get _stampPdf => "${Constants.baseUrl}/pdf-studio/stamp-pdf";
  static String get _placeImage => "${Constants.baseUrl}/pdf-studio/place-image";
  static String get _pdfToWord => "${Constants.baseUrl}/pdf-studio/pdf-to-word";
  static String get _pdfToExcel => "${Constants.baseUrl}/pdf-studio/pdf-to-excel";
  static String get _pdfToPptx => "${Constants.baseUrl}/pdf-studio/pdf-to-pptx";
  static String get _compressImage => "${Constants.baseUrl}/image-studio/compress-image";
  static String get _convertToJpg => "${Constants.baseUrl}/image-studio/convert-to-jpg";
  static String get _convertFromJpg => "${Constants.baseUrl}/image-studio/convert-from-jpg";
  static String get _resizeImage => "${Constants.baseUrl}/image-studio/resize-image";
  static String get _rotateImage => "${Constants.baseUrl}/image-studio/rotate-image";
  static String get _flipImage => "${Constants.baseUrl}/image-studio/flip-image";
  static String get _borderImage => "${Constants.baseUrl}/image-studio/border-image";
  static String get _mergePdf => "${Constants.baseUrl}/pdf-studio/merge-pdf";
  static String get _reorderPdf => "${Constants.baseUrl}/pdf-studio/reorder-pdf";
  static String get _splitPdf => "${Constants.baseUrl}/pdf-studio/split-pdf";
  static String get _pdfToJpg => "${Constants.baseUrl}/pdf-studio/pdf-to-jpg";
  static String get _imageToPdf => "${Constants.baseUrl}/pdf-studio/image-to-pdf";
  static String get _pageNumbers => "${Constants.baseUrl}/pdf-studio/page-numbers";
  static String get _rotatePdf => "${Constants.baseUrl}/pdf-studio/rotate-pdf";
  static String get _unprotectPdf => "${Constants.baseUrl}/pdf-studio/unprotect-pdf";
  static String get _protectpdf => "${Constants.baseUrl}/pdf-studio/protect-pdf";
  static String get _compressPdf => "${Constants.baseUrl}/pdf-studio/compress-pdf";
  static String get _watermarkPdf => "${Constants.baseUrl}/pdf-studio/watermark-pdf";
  static String get _extractText => "${Constants.baseUrl}/pdf-studio/extract-text";
  static String get _grayscalePdf => "${Constants.baseUrl}/pdf-studio/grayscale-pdf";
  static String get _cropPdf => "${Constants.baseUrl}/pdf-studio/crop-pdf";

  PdfService._();
  factory PdfService() {
    return _instance;
  }

  Future<Response<Uint8List>> mergePdf({required MergePdf mergePdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_mergePdf,data:FormData.fromMap(mergePdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> reorderPdf({required ReorderPdf reorderPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_reorderPdf,data:FormData.fromMap(reorderPdf.toJson()),options: Options( contentType: 'multipart/form-data', responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> splitPdf({required SplitPdf splitPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_splitPdf,data:FormData.fromMap(splitPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> pdfToJpg({required PdfToJpg pdfToJpg, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_pdfToJpg,data:FormData.fromMap(pdfToJpg.toJson()),options: Options(contentType: 'multipart/form-data',responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> imageToPdf({required ImageToPdf imageToPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_imageToPdf,data:FormData.fromMap(imageToPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> pageNumbers({required PageNumbers pageNumber, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_pageNumbers,data:FormData.fromMap(pageNumber.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> rotatePdf({required RotatePdf rotatePdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_rotatePdf,data:FormData.fromMap(rotatePdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> unprotectPdf({required UnProtectPdf unlockOdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_unprotectPdf,data:FormData.fromMap(unlockOdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> protectpdf({required ProtectPdf protectPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_protectpdf,data:FormData.fromMap(protectPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> compressPdf({required CompressPdf compressPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_compressPdf,data:FormData.fromMap(compressPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> watermarkPdf({required WatermarkPdf watermarkPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_watermarkPdf,data:FormData.fromMap(watermarkPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> extractText({required ExtractText extractText, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_extractText,data:FormData.fromMap(extractText.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> grayscalePdf({required GrayscalePdf grayscalePdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_grayscalePdf,data:FormData.fromMap(grayscalePdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> cropPdf({required CropPdf cropPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_cropPdf,data:FormData.fromMap(cropPdf.toJson()),options: Options(responseType: ResponseType.bytes),cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  /// Returns JSON metadata (title, author, subject, etc.) — not a file download.
  Future<Response<dynamic>> getMetadata({required GetMetadata getMetadata, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_getMetadata, data: FormData.fromMap(getMetadata.toJson()), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> editMetadata({required EditMetadata editMetadata, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_editMetadata, data: FormData.fromMap(editMetadata.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> headerFooter({required HeaderFooter headerFooter, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_headerFooter, data: FormData.fromMap(headerFooter.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> repairPdf({required RepairPdf repairPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_repairPdf, data: FormData.fromMap(repairPdf.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> flattenPdf({required FlattenPdf flattenPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_flattenPdf, data: FormData.fromMap(flattenPdf.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> addBlankPages({required AddBlankPages addBlankPages, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_addBlankPages, data: FormData.fromMap(addBlankPages.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> stampPdf({required StampPdf stampPdf, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_stampPdf, data: FormData.fromMap(stampPdf.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> placeImage({required PlaceImage placeImage, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_placeImage, data: FormData.fromMap(placeImage.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> compressImage({required CompressImage req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_compressImage, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> convertToJpg({required ConvertToJpg req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_convertToJpg, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> convertFromJpg({required ConvertFromJpg req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_convertFromJpg, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> resizeImage({required ResizeImage req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_resizeImage, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> rotateImage({required RotateImage req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_rotateImage, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> flipImage({required FlipImage req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_flipImage, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> borderImage({required BorderImage req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_borderImage, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> pdfToWord({required PdfToOffice req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_pdfToWord, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> pdfToExcel({required PdfToOffice req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_pdfToExcel, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> pdfToPptx({required PdfToOffice req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_pdfToPptx, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> redactPdf({required RedactPdf req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_redactPdf, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> duplicatePages({required DuplicatePages req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_duplicatePages, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  /// Returns the bookmark tree as JSON (not a file download).
  Future<Response<dynamic>> getBookmarks({required GetBookmarks req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_getBookmarks, data: FormData.fromMap(req.toJson()), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> editBookmarks({required EditBookmarks req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_editBookmarks, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> createForm({required CreateForm req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_createForm, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> removeMetadata({required RemoveMetadata req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_removeMetadata, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> extractImages({required ExtractImages req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_extractImages, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> sanitizePdf({required SanitizePdf req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_sanitizePdf, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> splitBySize({required SplitBySize req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_splitBySize, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> mirrorPdf({required MirrorPdf req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_mirrorPdf, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> resizePage({required ResizePage req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_resizePage, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> scalePdf({required ScalePdf req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_scalePdf, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> insertPdf({required InsertPdf req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_insertPdf, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> extractEmbeddedFiles({required ExtractEmbeddedFiles req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_extractEmbedded, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  /// Returns a JSON analysis report — not a file download.
  Future<Response<dynamic>> analyzePdf({required AnalyzePdf req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_analyzePdf, data: FormData.fromMap(req.toJson()), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> replacePages({required ReplacePages req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_replacePages, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> extractFonts({required ExtractFonts req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_extractFonts, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> filterImage({required FilterImage req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_filterImage, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> removeBlankPages({required RemoveBlankPages req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_removeBlankPages, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> optimizePdf({required OptimizePdf req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_optimizePdf, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }

  Future<Response<Uint8List>> nUpPdf({required NUp req, CancelToken? cancelToken, ProgressCallback? onSendProgress}) async {
    return await DioSingleton().dio.post(_nUpPdf, data: FormData.fromMap(req.toJson()), options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken, onSendProgress: onSendProgress);
  }
}
