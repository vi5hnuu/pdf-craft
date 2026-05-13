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
import 'package:pdf_craft/models/request/unlock-pdf.dart';
import 'package:pdf_craft/models/request/watermark-pdf.dart';
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
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.error(error: e.message ?? error))));
    } catch (_) {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(key, HttpState.error(error: error))));
    }
  }

  String _extractFilenameFromContentDisposition(String? contentDisposition) {
    if (contentDisposition != null) {
      final match = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
      if (match != null) return match.group(1)!;
    }
    return 'default_filename.pdf';
  }

  Future<File> _saveFileToProcessed(Response<Uint8List> fileRes) async {
    if (!await StoragePermissions.requestStoragePermissions()) {
      throw Exception('Failed to save — storage permission denied');
    }
    final directory = Directory(Constants.processedDirPath);
    if (!directory.existsSync()) await directory.create(recursive: true);
    final contentDisposition = fileRes.headers.value('content-disposition');
    final dummyName = 'file_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filename = contentDisposition?.split('=').last ?? dummyName;
    var file = File('${directory.path}/$filename');
    if (file.existsSync()) file = File('${directory.path}/$dummyName');
    await file.writeAsBytes(fileRes.data!);
    return file;
  }
}
