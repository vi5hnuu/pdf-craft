import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/WithHttpState.dart';
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
import 'package:pdf_craft/models/request/filter-image.dart';
import 'package:pdf_craft/models/request/remove-blank-pages.dart';
import 'package:pdf_craft/models/request/optimize-pdf.dart';
import 'package:pdf_craft/models/request/n-up.dart';
import 'package:pdf_craft/services/apis/PdfService.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import '../../models/HttpState.dart';
part 'pdf_event.dart';
part 'pdf_state.dart';

class PdfBloc extends Bloc<PdfEvent, PdfState> {
  final PdfService _pdfService;

  PdfBloc({required PdfService pdfService})
      : _pdfService = pdfService,
        super(PdfState.initial()) {

    // Clears leftover state for the given keys so a re-opened tool screen starts
    // clean (prevents stale done/error from a prior run firing on mount).
    on<ResetHttpStateEvent>((e, emit) {
      final states = state.httpStates.clone();
      for (final key in e.keys) {
        states.remove(key);
      }
      emit(state.copyWith(httpStates: states));
    });

    on<MergePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.MERGE_PDF,
      call: (p) => _pdfService.mergePdf(mergePdf: e.mergePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to merge PDFs',
    ));

    on<ReorderPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.REORDER_PDF,
      call: (p) => _pdfService.reorderPdf(reorderPdf: e.reorderPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to reorder pages',
    ));

    on<SplitPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.SPLIT_PDF,
      call: (p) => _pdfService.splitPdf(splitPdf: e.splitPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to split PDF',
    ));

    on<PdfToJpgEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.PDF_TO_JPG,
      call: (p) => _pdfService.pdfToJpg(pdfToJpg: e.pdfToJpg, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to convert PDF to JPG',
    ));

    on<ImageToPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.IMAGE_TO_PDF,
      call: (p) => _pdfService.imageToPdf(imageToPdf: e.imageToPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to convert images to PDF',
    ));

    on<PageNumbersEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.PAGE_NUMBERS,
      call: (p) => _pdfService.pageNumbers(pageNumber: e.pageNumber, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to add page numbers',
    ));

    on<RotatePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.ROTATE_PDF,
      call: (p) => _pdfService.rotatePdf(rotatePdf: e.rotatePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to rotate PDF',
    ));

    on<UnprotectPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.UNPROTECT_PDF,
      call: (p) => _pdfService.unprotectPdf(unlockOdf: e.unlockPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to remove password',
    ));

    on<ProtectPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.PROTECT_PDF,
      call: (p) => _pdfService.protectpdf(protectPdf: e.protectPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to protect PDF',
    ));

    on<CompressPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.COMPRESS_PDF,
      call: (p) => _pdfService.compressPdf(compressPdf: e.compressPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to compress PDF',
    ));

    on<WatermarkPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.WATERMARK_PDF,
      call: (p) => _pdfService.watermarkPdf(watermarkPdf: e.watermarkPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to add watermark',
    ));

    on<ExtractTextEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.EXTRACT_TEXT,
      call: (p) => _pdfService.extractText(extractText: e.extractText, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to extract text',
    ));

    on<GrayscalePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.GRAYSCALE_PDF,
      call: (p) => _pdfService.grayscalePdf(grayscalePdf: e.grayscalePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to convert to grayscale',
    ));

    on<CropPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.CROP_PDF,
      call: (p) => _pdfService.cropPdf(cropPdf: e.cropPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to crop PDF',
    ));

    on<EditMetadataEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.EDIT_METADATA,
      call: (p) => _pdfService.editMetadata(editMetadata: e.editMetadata, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to edit metadata',
    ));

    on<HeaderFooterEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.HEADER_FOOTER,
      call: (p) => _pdfService.headerFooter(headerFooter: e.headerFooter, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to add header/footer',
    ));

    on<RepairPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.REPAIR_PDF,
      call: (p) => _pdfService.repairPdf(repairPdf: e.repairPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to repair PDF',
    ));

    on<FlattenPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.FLATTEN_PDF,
      call: (p) => _pdfService.flattenPdf(flattenPdf: e.flattenPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to flatten PDF',
    ));

    on<AddBlankPagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.ADD_BLANK_PAGES,
      call: (p) => _pdfService.addBlankPages(addBlankPages: e.addBlankPages, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to add blank pages',
    ));

    on<StampPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.STAMP_PDF,
      call: (p) => _pdfService.stampPdf(stampPdf: e.stampPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to stamp PDF',
    ));

    on<PlaceImageEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.PLACE_IMAGE,
      call: (p) => _pdfService.placeImage(placeImage: e.placeImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to place image on PDF',
    ));

    on<CompressImageEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.compressImage(req: e.compressImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to compress image',
    ));

    on<ConvertToJpgEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.convertToJpg(req: e.convertToJpg, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to convert image to JPG',
    ));

    on<ConvertFromJpgEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.convertFromJpg(req: e.convertFromJpg, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to convert image from JPG',
    ));

    on<ResizeImageEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.resizeImage(req: e.resizeImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to resize image',
    ));

    on<PdfToOfficeEvent>((e, emit) {
      final key = switch (e.pdfToOffice.format) {
        PdfOfficeFormat.word => HttpStates.PDF_TO_WORD,
        PdfOfficeFormat.excel => HttpStates.PDF_TO_EXCEL,
        PdfOfficeFormat.pptx => HttpStates.PDF_TO_PPTX,
      };
      final call = switch (e.pdfToOffice.format) {
        PdfOfficeFormat.word =>
          (ProgressCallback p) => _pdfService.pdfToWord(req: e.pdfToOffice, cancelToken: e.cancelToken, onSendProgress: p),
        PdfOfficeFormat.excel =>
          (ProgressCallback p) => _pdfService.pdfToExcel(req: e.pdfToOffice, cancelToken: e.cancelToken, onSendProgress: p),
        PdfOfficeFormat.pptx =>
          (ProgressCallback p) => _pdfService.pdfToPptx(req: e.pdfToOffice, cancelToken: e.cancelToken, onSendProgress: p),
      };
      return _handle(emit: emit, key: key, call: call, error: 'Conversion failed');
    });

    on<RedactPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.REDACT_PDF,
      call: (p) => _pdfService.redactPdf(req: e.redactPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to redact PDF',
    ));

    on<DuplicatePagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.DUPLICATE_PAGES,
      call: (p) => _pdfService.duplicatePages(req: e.duplicatePages, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to duplicate pages',
    ));

    on<EditBookmarksEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.EDIT_BOOKMARKS,
      call: (p) => _pdfService.editBookmarks(req: e.editBookmarks, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to edit bookmarks',
    ));

    on<CreateFormEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.CREATE_FORM,
      call: (p) => _pdfService.createForm(req: e.createForm, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to create form',
    ));

    on<RemoveMetadataEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.REMOVE_METADATA,
      call: (p) => _pdfService.removeMetadata(req: e.removeMetadata, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to remove metadata',
    ));

    on<ExtractImagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.EXTRACT_IMAGES,
      call: (p) => _pdfService.extractImages(req: e.extractImages, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to extract images',
    ));

    on<SanitizePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.SANITIZE_PDF,
      call: (p) => _pdfService.sanitizePdf(req: e.sanitizePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to sanitize PDF',
    ));

    on<SplitBySizeEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.SPLIT_BY_SIZE,
      call: (p) => _pdfService.splitBySize(req: e.splitBySize, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to split PDF',
    ));

    on<MirrorPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.MIRROR_PDF,
      call: (p) => _pdfService.mirrorPdf(req: e.mirrorPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to mirror PDF',
    ));

    on<ResizePageEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.RESIZE_PAGE,
      call: (p) => _pdfService.resizePage(req: e.resizePage, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to resize pages',
    ));

    on<ScalePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.SCALE_PDF,
      call: (p) => _pdfService.scalePdf(req: e.scalePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to scale PDF',
    ));

    on<InsertPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.INSERT_PDF,
      call: (p) => _pdfService.insertPdf(req: e.insertPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to insert PDF',
    ));

    on<ExtractEmbeddedFilesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.EXTRACT_EMBEDDED,
      call: (p) => _pdfService.extractEmbeddedFiles(req: e.extractEmbeddedFiles, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to extract embedded files',
    ));

    on<ReplacePagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.REPLACE_PAGES,
      call: (p) => _pdfService.replacePages(req: e.replacePages, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to replace pages',
    ));

    on<ExtractFontsEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.EXTRACT_FONTS,
      call: (p) => _pdfService.extractFonts(req: e.extractFonts, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to extract fonts',
    ));

    // Returns a JSON analysis report — does not save a file.
    on<AnalyzePdfEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ANALYZE_PDF, const HttpState.loading())));
      try {
        final res = await _pdfService.analyzePdf(req: event.analyzePdf, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ANALYZE_PDF, HttpState.done(extras: {'analysis': res.data}))));
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          emit(state.copyWith(httpStates: state.httpStates.clone()..remove(HttpStates.ANALYZE_PDF)));
        } else {
          emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ANALYZE_PDF, HttpState.error(error: e.message ?? 'Failed to analyze PDF'))));
        }
      } catch (_) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ANALYZE_PDF, const HttpState.error(error: 'Failed to analyze PDF'))));
      }
    });

    on<FilterImageEvent>((e, emit) => _handleImage(
      emit: emit,
      key: HttpStates.FILTER_IMAGE,
      call: (p) => _pdfService.filterImage(req: e.filterImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to apply filter',
    ));

    on<RemoveBlankPagesEvent>((e, emit) => _handle(
      emit: emit,
      key: HttpStates.REMOVE_BLANK_PAGES,
      call: (p) => _pdfService.removeBlankPages(req: e.removeBlankPages, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to remove blank pages',
    ));

    on<OptimizePdfEvent>((e, emit) => _handle(
      emit: emit,
      key: HttpStates.OPTIMIZE_PDF,
      call: (p) => _pdfService.optimizePdf(req: e.optimizePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to optimize PDF',
    ));

    on<NUpPdfEvent>((e, emit) => _handle(
      emit: emit,
      key: HttpStates.N_UP_PDF,
      call: (p) => _pdfService.nUpPdf(req: e.nUp, cancelToken: e.cancelToken, onSendProgress: p),
      error: 'Failed to create N-up PDF',
    ));

    // Returns JSON bookmark tree — does not save a file
    on<GetBookmarksEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_BOOKMARKS, const HttpState.loading())));
      try {
        final res = await _pdfService.getBookmarks(req: event.getBookmarks, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_BOOKMARKS, HttpState.done(extras: {'bookmarks': res.data}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_BOOKMARKS, HttpState.error(error: e.message ?? 'Failed to get bookmarks'))));
      } catch (_) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_BOOKMARKS, const HttpState.error(error: 'Failed to get bookmarks'))));
      }
    });

    // Returns JSON metadata — does not save a file
    on<GetMetadataEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, const HttpState.loading())));
      try {
        final res = await _pdfService.getMetadata(getMetadata: event.getMetadata, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, HttpState.done(extras: {'metadata': res.data}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, HttpState.error(error: e.message ?? 'Failed to get metadata'))));
      } catch (_) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, const HttpState.error(error: 'Failed to get metadata'))));
      }
    });
  }

  // Shared handler: emits loading → upload progress → done/error
  Future<void> _handle({
    required Emitter<PdfState> emit,
    required String key,
    required Future<Response<Uint8List>> Function(ProgressCallback onSendProgress) call,
    required String error,
  }) async {
    emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, const HttpState.loading())));
    try {
      final res = await call((sent, total) {
        if (total > 0) {
          emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.loading(progress: sent / total))));
        }
      });
      if (res.data == null) throw Exception(error);
      final file = await _saveFileToProcessed(res);
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.done(extras: {'savedFile': file}))));
    } on DioException catch (e) {
      // A user-cancelled request should leave no error behind — reset to idle.
      if (e.type == DioExceptionType.cancel) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..remove(key)));
      } else {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.error(error: e.message ?? error))));
      }
    } catch (_) {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.error(error: error))));
    }
  }

  // Handler for image-studio operations — saves to processed dir with image extension
  Future<void> _handleImage({
    required Emitter<PdfState> emit,
    String key = HttpStates.IMAGE_STUDIO,
    required Future<Response<Uint8List>> Function(ProgressCallback onSendProgress) call,
    required String error,
  }) async {
    emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, const HttpState.loading())));
    try {
      final res = await call((sent, total) {
        if (total > 0) {
          emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.loading(progress: sent / total))));
        }
      });
      if (res.data == null) throw Exception(error);
      final file = await _saveImageToProcessed(res);
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.done(extras: {'savedFile': file}))));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..remove(key)));
      } else {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.error(error: e.message ?? error))));
      }
    } catch (_) {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.error(error: error))));
    }
  }

  Future<File> _saveImageToProcessed(Response<Uint8List> fileRes) async {
    return _saveBytesToProcessed(fileRes, fallbackPrefix: 'image', fallbackExt: 'jpg');
  }

  Future<File> _saveFileToProcessed(Response<Uint8List> fileRes) async {
    return _saveBytesToProcessed(fileRes, fallbackPrefix: 'file', fallbackExt: 'pdf');
  }

  /// Persists a downloaded response to the processed directory using the server's
  /// suggested filename (Content-Disposition), falling back to a timestamped name.
  /// Guarantees the final path does not collide with an existing file.
  Future<File> _saveBytesToProcessed(
    Response<Uint8List> fileRes, {
    required String fallbackPrefix,
    required String fallbackExt,
  }) async {
    if (!await StoragePermissions.requestStoragePermissions()) {
      throw Exception('Failed to save — storage permission denied');
    }
    final directory = Directory(Constants.processedDirPath);
    if (!directory.existsSync()) await directory.create(recursive: true);

    final fallback = '${fallbackPrefix}_${DateTime.now().millisecondsSinceEpoch}.$fallbackExt';
    final suggested = _filenameFromContentDisposition(fileRes.headers.value('content-disposition')) ?? fallback;
    final file = File(_uniquePath(directory.path, suggested));
    await file.writeAsBytes(fileRes.data!);
    return file;
  }

  /// Parses a filename out of a Content-Disposition header, handling both the
  /// RFC 5987 `filename*=UTF-8''name.ext` form and the plain/quoted `filename=`
  /// form. Returns null when no usable name is present.
  String? _filenameFromContentDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    // Prefer the extended (filename*) form when present.
    final ext = RegExp(r"filename\*\s*=\s*[^']*''([^;]+)", caseSensitive: false).firstMatch(header);
    if (ext != null) {
      final decoded = Uri.decodeComponent(ext.group(1)!.trim());
      if (decoded.isNotEmpty) return _sanitizeName(decoded);
    }
    final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false).firstMatch(header);
    if (plain != null) {
      final name = plain.group(1)!.trim();
      if (name.isNotEmpty) return _sanitizeName(name);
    }
    return null;
  }

  /// Strips any path separators a malicious/odd header might inject.
  String _sanitizeName(String name) => name.split(RegExp(r'[\\/]')).last;

  /// Returns a path in [dir] for [name], appending " (n)" before the extension
  /// until it no longer collides with an existing file.
  String _uniquePath(String dir, String name) {
    var candidate = File('$dir/$name');
    if (!candidate.existsSync()) return candidate.path;
    final dot = name.lastIndexOf('.');
    final base = dot == -1 ? name : name.substring(0, dot);
    final ext = dot == -1 ? '' : name.substring(dot);
    var n = 1;
    do {
      candidate = File('$dir/$base ($n)$ext');
      n++;
    } while (candidate.existsSync());
    return candidate.path;
  }
}
