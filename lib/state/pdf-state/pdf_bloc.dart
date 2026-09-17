import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/extensions/map_entensions.dart';
import 'package:pdf_craft/models/with_http_state.dart';
import 'package:pdf_craft/models/request/add_blank_pages.dart';
import 'package:pdf_craft/models/request/compress_pdf.dart';
import 'package:pdf_craft/models/request/crop_pdf.dart';
import 'package:pdf_craft/models/request/edit_metadata.dart';
import 'package:pdf_craft/models/request/extract_text.dart';
import 'package:pdf_craft/models/request/flatten_pdf.dart';
import 'package:pdf_craft/models/request/get_metadata.dart';
import 'package:pdf_craft/models/request/grayscale_pdf.dart';
import 'package:pdf_craft/models/request/header_footer.dart';
import 'package:pdf_craft/models/request/image_to_pdf.dart';
import 'package:pdf_craft/models/request/merge_pdf.dart';
import 'package:pdf_craft/models/request/page_numbers.dart';
import 'package:pdf_craft/models/request/pdf_to_jpg.dart';
import 'package:pdf_craft/models/request/protect_pdf.dart';
import 'package:pdf_craft/models/request/repair_pdf.dart';
import 'package:pdf_craft/models/request/reorder_pdf.dart';
import 'package:pdf_craft/models/request/rotate_pdf.dart';
import 'package:pdf_craft/models/request/split_pdf.dart';
import 'package:pdf_craft/models/request/stamp_pdf.dart';
import 'package:pdf_craft/models/request/place_image.dart';
import 'package:pdf_craft/models/request/image_studio.dart';
import 'package:pdf_craft/models/request/pdf_to_office.dart';
import 'package:pdf_craft/models/request/unlock_pdf.dart';
import 'package:pdf_craft/models/request/watermark_pdf.dart';
import 'package:pdf_craft/models/request/redact_pdf.dart';
import 'package:pdf_craft/models/request/duplicate_pages.dart';
import 'package:pdf_craft/models/request/get_bookmarks.dart';
import 'package:pdf_craft/models/request/edit_bookmarks.dart';
import 'package:pdf_craft/models/request/create_form.dart';
import 'package:pdf_craft/models/request/remove_metadata.dart';
import 'package:pdf_craft/models/request/extract_images.dart';
import 'package:pdf_craft/models/request/sanitize_pdf.dart';
import 'package:pdf_craft/models/request/split_by_size.dart';
import 'package:pdf_craft/models/request/mirror_pdf.dart';
import 'package:pdf_craft/models/request/resize_page.dart';
import 'package:pdf_craft/models/request/scale_pdf.dart';
import 'package:pdf_craft/models/request/insert_pdf.dart';
import 'package:pdf_craft/models/request/extract_embedded_files.dart';
import 'package:pdf_craft/models/request/analyze_pdf.dart';
import 'package:pdf_craft/models/request/replace_pages.dart';
import 'package:pdf_craft/models/request/extract_fonts.dart';
import 'package:pdf_craft/models/request/rotate_image.dart';
import 'package:pdf_craft/models/request/flip_image.dart';
import 'package:pdf_craft/models/request/border_image.dart';
import 'package:pdf_craft/models/request/get_form_fields.dart';
import 'package:pdf_craft/models/request/fill_flatten.dart';
import 'package:pdf_craft/models/request/filter_image.dart';
import 'package:pdf_craft/models/request/remove_blank_pages.dart';
import 'package:pdf_craft/models/request/optimize_pdf.dart';
import 'package:pdf_craft/models/request/n_up.dart';
import 'package:pdf_craft/services/apis/pdf_service.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/storage_permissions.dart';
import 'package:pdf_craft/utils/http_states.dart';
import '../../models/http_state.dart';
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
      emit: emit, key: HttpStates.mergePdf,
      call: (p) => _pdfService.mergePdf(mergePdf: e.mergePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ReorderPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.reorderPdf,
      call: (p) => _pdfService.reorderPdf(reorderPdf: e.reorderPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<SplitPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.splitPdf,
      call: (p) => _pdfService.splitPdf(splitPdf: e.splitPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<PdfToJpgEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.pdfToJpg,
      call: (p) => _pdfService.pdfToJpg(pdfToJpg: e.pdfToJpg, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ImageToPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.imageToPdf,
      call: (p) => _pdfService.imageToPdf(imageToPdf: e.imageToPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<PageNumbersEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.pageNumbers,
      call: (p) => _pdfService.pageNumbers(pageNumber: e.pageNumber, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<RotatePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.rotatePdf,
      call: (p) => _pdfService.rotatePdf(rotatePdf: e.rotatePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<UnprotectPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.unprotectPdf,
      call: (p) => _pdfService.unprotectPdf(unlockOdf: e.unlockPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ProtectPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.protectPdf,
      call: (p) => _pdfService.protectpdf(protectPdf: e.protectPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<CompressPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.compressPdf,
      call: (p) => _pdfService.compressPdf(compressPdf: e.compressPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<WatermarkPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.watermarkPdf,
      call: (p) => _pdfService.watermarkPdf(watermarkPdf: e.watermarkPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ExtractTextEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.extractText,
      call: (p) => _pdfService.extractText(extractText: e.extractText, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<GrayscalePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.grayscalePdf,
      call: (p) => _pdfService.grayscalePdf(grayscalePdf: e.grayscalePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<CropPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.cropPdf,
      call: (p) => _pdfService.cropPdf(cropPdf: e.cropPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<EditMetadataEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.editMetadata,
      call: (p) => _pdfService.editMetadata(editMetadata: e.editMetadata, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<HeaderFooterEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.headerFooter,
      call: (p) => _pdfService.headerFooter(headerFooter: e.headerFooter, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<RepairPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.repairPdf,
      call: (p) => _pdfService.repairPdf(repairPdf: e.repairPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<FlattenPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.flattenPdf,
      call: (p) => _pdfService.flattenPdf(flattenPdf: e.flattenPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<AddBlankPagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.addBlankPages,
      call: (p) => _pdfService.addBlankPages(addBlankPages: e.addBlankPages, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<StampPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.stampPdf,
      call: (p) => _pdfService.stampPdf(stampPdf: e.stampPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<PlaceImageEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.placeImage,
      call: (p) => _pdfService.placeImage(placeImage: e.placeImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<CompressImageEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.compressImage(req: e.compressImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ConvertToJpgEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.convertToJpg(req: e.convertToJpg, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ConvertFromJpgEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.convertFromJpg(req: e.convertFromJpg, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ResizeImageEvent>((e, emit) => _handleImage(
      emit: emit,
      call: (p) => _pdfService.resizeImage(req: e.resizeImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<RotateImageEvent>((e, emit) => _handleImage(
      emit: emit, key: HttpStates.rotateImage,
      call: (p) => _pdfService.rotateImage(req: e.rotateImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<FlipImageEvent>((e, emit) => _handleImage(
      emit: emit, key: HttpStates.flipImage,
      call: (p) => _pdfService.flipImage(req: e.flipImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<BorderImageEvent>((e, emit) => _handleImage(
      emit: emit, key: HttpStates.borderImage,
      call: (p) => _pdfService.borderImage(req: e.borderImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<FillFlattenEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.fillFlatten,
      call: (p) => _pdfService.fillFlatten(req: e.fillFlatten, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    // Returns the PDF's existing form fields as JSON — does not save a file.
    on<GetFormFieldsEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getFormFields, const HttpState.loading())));
      try {
        final res = await _pdfService.getFormFields(req: event.getFormFields, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getFormFields, HttpState.done(extras: {'fields': res.data}))));
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          emit(state.copyWith(httpStates: state.httpStates.clone()..remove(HttpStates.getFormFields)));
        } else {
          emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getFormFields, HttpState.fromDio(e, L10n.current.errToolFailed))));
        }
      } catch (_) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getFormFields, HttpState.error(error: L10n.current.errToolFailed))));
      }
    });

    on<PdfToOfficeEvent>((e, emit) {
      final key = switch (e.pdfToOffice.format) {
        PdfOfficeFormat.word => HttpStates.pdfToWord,
        PdfOfficeFormat.excel => HttpStates.pdfToExcel,
        PdfOfficeFormat.pptx => HttpStates.pdfToPptx,
      };
      final call = switch (e.pdfToOffice.format) {
        PdfOfficeFormat.word =>
          (ProgressCallback p) => _pdfService.pdfToWord(req: e.pdfToOffice, cancelToken: e.cancelToken, onSendProgress: p),
        PdfOfficeFormat.excel =>
          (ProgressCallback p) => _pdfService.pdfToExcel(req: e.pdfToOffice, cancelToken: e.cancelToken, onSendProgress: p),
        PdfOfficeFormat.pptx =>
          (ProgressCallback p) => _pdfService.pdfToPptx(req: e.pdfToOffice, cancelToken: e.cancelToken, onSendProgress: p),
      };
      return _handle(emit: emit, key: key, call: call, error: L10n.current.errToolFailed);
    });

    on<RedactPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.redactPdf,
      call: (p) => _pdfService.redactPdf(req: e.redactPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<DuplicatePagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.duplicatePages,
      call: (p) => _pdfService.duplicatePages(req: e.duplicatePages, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<EditBookmarksEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.editBookmarks,
      call: (p) => _pdfService.editBookmarks(req: e.editBookmarks, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<CreateFormEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.createForm,
      call: (p) => _pdfService.createForm(req: e.createForm, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<RemoveMetadataEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.removeMetadata,
      call: (p) => _pdfService.removeMetadata(req: e.removeMetadata, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ExtractImagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.extractImages,
      call: (p) => _pdfService.extractImages(req: e.extractImages, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<SanitizePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.sanitizePdf,
      call: (p) => _pdfService.sanitizePdf(req: e.sanitizePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<SplitBySizeEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.splitBySize,
      call: (p) => _pdfService.splitBySize(req: e.splitBySize, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<MirrorPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.mirrorPdf,
      call: (p) => _pdfService.mirrorPdf(req: e.mirrorPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ResizePageEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.resizePage,
      call: (p) => _pdfService.resizePage(req: e.resizePage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ScalePdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.scalePdf,
      call: (p) => _pdfService.scalePdf(req: e.scalePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<InsertPdfEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.insertPdf,
      call: (p) => _pdfService.insertPdf(req: e.insertPdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ExtractEmbeddedFilesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.extractEmbedded,
      call: (p) => _pdfService.extractEmbeddedFiles(req: e.extractEmbeddedFiles, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ReplacePagesEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.replacePages,
      call: (p) => _pdfService.replacePages(req: e.replacePages, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<ExtractFontsEvent>((e, emit) => _handle(
      emit: emit, key: HttpStates.extractFonts,
      call: (p) => _pdfService.extractFonts(req: e.extractFonts, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    // Returns a JSON analysis report — does not save a file.
    on<AnalyzePdfEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.analyzePdf, const HttpState.loading())));
      try {
        final res = await _pdfService.analyzePdf(req: event.analyzePdf, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.analyzePdf, HttpState.done(extras: {'analysis': res.data}))));
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          emit(state.copyWith(httpStates: state.httpStates.clone()..remove(HttpStates.analyzePdf)));
        } else {
          emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.analyzePdf, HttpState.fromDio(e, L10n.current.errToolFailed))));
        }
      } catch (_) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.analyzePdf, HttpState.error(error: L10n.current.errToolFailed))));
      }
    });

    on<FilterImageEvent>((e, emit) => _handleImage(
      emit: emit,
      key: HttpStates.filterImage,
      call: (p) => _pdfService.filterImage(req: e.filterImage, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<RemoveBlankPagesEvent>((e, emit) => _handle(
      emit: emit,
      key: HttpStates.removeBlankPages,
      call: (p) => _pdfService.removeBlankPages(req: e.removeBlankPages, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<OptimizePdfEvent>((e, emit) => _handle(
      emit: emit,
      key: HttpStates.optimizePdf,
      call: (p) => _pdfService.optimizePdf(req: e.optimizePdf, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    on<NUpPdfEvent>((e, emit) => _handle(
      emit: emit,
      key: HttpStates.nUpPdf,
      call: (p) => _pdfService.nUpPdf(req: e.nUp, cancelToken: e.cancelToken, onSendProgress: p),
      error: L10n.current.errToolFailed,
    ));

    // Returns JSON bookmark tree — does not save a file
    on<GetBookmarksEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getBookmarks, const HttpState.loading())));
      try {
        final res = await _pdfService.getBookmarks(req: event.getBookmarks, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getBookmarks, HttpState.done(extras: {'bookmarks': res.data}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getBookmarks, HttpState.fromDio(e, L10n.current.errToolFailed))));
      } catch (_) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getBookmarks, HttpState.error(error: L10n.current.errToolFailed))));
      }
    });

    // Returns JSON metadata — does not save a file
    on<GetMetadataEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getMetadata, const HttpState.loading())));
      try {
        final res = await _pdfService.getMetadata(getMetadata: event.getMetadata, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getMetadata, HttpState.done(extras: {'metadata': res.data}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getMetadata, HttpState.fromDio(e, L10n.current.errToolFailed))));
      } catch (_) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.getMetadata, HttpState.error(error: L10n.current.errToolFailed))));
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
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.fromDio(e, error))));
      }
    } catch (_) {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.error(error: error))));
    }
  }

  // Handler for image-studio operations — saves to processed dir with image extension
  Future<void> _handleImage({
    required Emitter<PdfState> emit,
    String key = HttpStates.imageStudio,
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
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.fromDio(e, error))));
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
      throw Exception(L10n.current.errToolFailed);
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
