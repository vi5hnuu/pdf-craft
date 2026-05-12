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
  PdfBloc({required PdfService pdfService}) : super(PdfState.initial()) {

    on<MergePdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MERGE_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.mergePdf(mergePdf: event.mergePdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to merge file/s");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.MERGE_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MERGE_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MERGE_PDF, HttpState.error(error: e.toString()))));
      }
    });

    on<ReorderPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REORDER_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.reorderPdf(reorderPdf:event.reorderPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to reorder pdf page/s");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.REORDER_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REORDER_PDF, HttpState.error(error:"Failed to reorder pages."))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REORDER_PDF, HttpState.error(error: "Failed to reorder pages."))));
      }
    });

    on<SplitPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.SPLIT_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.splitPdf(splitPdf:event.splitPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception();
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.SPLIT_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.SPLIT_PDF, HttpState.error(error:"Failed to split pdf file"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.SPLIT_PDF, HttpState.error(error: "Failed to split pdf file"))));
      }
    });

    on<PdfToJpgEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PDF_TO_JPG,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.pdfToJpg(pdfToJpg:event.pdfToJpg,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception();
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.PDF_TO_JPG,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PDF_TO_JPG, const HttpState.error(error:"Failed to convert pdf to jpg"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PDF_TO_JPG, const HttpState.error(error: "Failed to convert pdf to jpg"))));
      }
    });

    on<ImageToPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.imageToPdf(imageToPdf:event.imageToPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to convert images to pdf page");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF, HttpState.error(error:"Failed to convert images to pdf page"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF, HttpState.error(error: "Failed to convert images to pdf page"))));
      }
    });

    on<PageNumbersEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.pageNumbers(pageNumber:event.pageNumber,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to write page type");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS, HttpState.error(error:"Failed to write page type."))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS, HttpState.error(error: "Failed to write page type."))));
      }
    });

    on<RotatePdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ROTATE_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.rotatePdf(rotatePdf:event.rotatePdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception();
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.ROTATE_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ROTATE_PDF, HttpState.error(error:"Failed to Rotate page/s"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ROTATE_PDF, HttpState.error(error: "Failed to Rotate page/s"))));
      }
    });

    on<UnprotectPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.UNPROTECT_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.unprotectPdf(unlockOdf:event.unlockPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception();
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.UNPROTECT_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.UNPROTECT_PDF, HttpState.error(error:e.message ?? "Failed to un-protect pdf/Or already unprotected"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.UNPROTECT_PDF, HttpState.error(error: "Failed to un-protect pdf"))));
      }
    });

    on<ProtectPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PROTECT_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.protectpdf(protectPdf:event.protectPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception();
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.PROTECT_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PROTECT_PDF, HttpState.error(error:"Failed to protect pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PROTECT_PDF, HttpState.error(error: "Failed to protect pdf"))));
      }
    });

    on<CompressPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.COMPRESS_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.compressPdf(compressPdf:event.compressPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to compress pdf");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.COMPRESS_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.COMPRESS_PDF, HttpState.error(error:"Failed to compress pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.COMPRESS_PDF, HttpState.error(error: "Failed to compress pdf"))));
      }
    });

    on<WatermarkPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.WATERMARK_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.watermarkPdf(watermarkPdf:event.watermarkPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to watermark pdf");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.WATERMARK_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.WATERMARK_PDF, HttpState.error(error:"Failed to watermark pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.WATERMARK_PDF, HttpState.error(error: "Failed to watermark pdf"))));
      }
    });

    on<ExtractTextEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.EXTRACT_TEXT,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.extractText(extractText:event.extractText,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to extract text");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.EXTRACT_TEXT,HttpState.done(extras: {'savedFile':saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.EXTRACT_TEXT, HttpState.error(error:"Failed to extract text from pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.EXTRACT_TEXT, HttpState.error(error: "Failed to extract text from pdf"))));
      }
    });

    on<GrayscalePdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GRAYSCALE_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.grayscalePdf(grayscalePdf:event.grayscalePdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to convert pdf to grayscale");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.GRAYSCALE_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GRAYSCALE_PDF, HttpState.error(error:"Failed to convert pdf to grayscale"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GRAYSCALE_PDF, HttpState.error(error: "Failed to convert pdf to grayscale"))));
      }
    });

    on<CropPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.CROP_PDF,const HttpState.loading())));
      try {
        Response<Uint8List> fileRes =await pdfService.cropPdf(cropPdf:event.cropPdf,cancelToken: event.cancelToken);
        if(fileRes.data==null) throw Exception("Failed to crop pdf");
        File saveFile=await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.CROP_PDF,HttpState.done(extras: {'savedFile':saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.CROP_PDF, HttpState.error(error:"Failed to crop pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.CROP_PDF, HttpState.error(error: "Failed to crop pdf"))));
      }
    });

    // Returns JSON metadata in extras['metadata'] — no file saved
    on<GetMetadataEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, const HttpState.loading())));
      try {
        final res = await pdfService.getMetadata(getMetadata: event.getMetadata, cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, HttpState.done(extras: {'metadata': res.data}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, HttpState.error(error: e.message ?? "Failed to get metadata"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.GET_METADATA, HttpState.error(error: "Failed to get metadata"))));
      }
    });

    on<EditMetadataEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.EDIT_METADATA, const HttpState.loading())));
      try {
        Response<Uint8List> fileRes = await pdfService.editMetadata(editMetadata: event.editMetadata, cancelToken: event.cancelToken);
        if (fileRes.data == null) throw Exception("Failed to edit metadata");
        File saveFile = await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.EDIT_METADATA, HttpState.done(extras: {'savedFile': saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.EDIT_METADATA, HttpState.error(error: "Failed to edit metadata"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.EDIT_METADATA, HttpState.error(error: "Failed to edit metadata"))));
      }
    });

    on<HeaderFooterEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.HEADER_FOOTER, const HttpState.loading())));
      try {
        Response<Uint8List> fileRes = await pdfService.headerFooter(headerFooter: event.headerFooter, cancelToken: event.cancelToken);
        if (fileRes.data == null) throw Exception("Failed to add header/footer");
        File saveFile = await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.HEADER_FOOTER, HttpState.done(extras: {'savedFile': saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.HEADER_FOOTER, HttpState.error(error: "Failed to add header/footer"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.HEADER_FOOTER, HttpState.error(error: "Failed to add header/footer"))));
      }
    });

    on<RepairPdfEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REPAIR_PDF, const HttpState.loading())));
      try {
        Response<Uint8List> fileRes = await pdfService.repairPdf(repairPdf: event.repairPdf, cancelToken: event.cancelToken);
        if (fileRes.data == null) throw Exception("Failed to repair pdf");
        File saveFile = await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REPAIR_PDF, HttpState.done(extras: {'savedFile': saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REPAIR_PDF, HttpState.error(error: "Failed to repair pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REPAIR_PDF, HttpState.error(error: "Failed to repair pdf"))));
      }
    });

    on<FlattenPdfEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.FLATTEN_PDF, const HttpState.loading())));
      try {
        Response<Uint8List> fileRes = await pdfService.flattenPdf(flattenPdf: event.flattenPdf, cancelToken: event.cancelToken);
        if (fileRes.data == null) throw Exception("Failed to flatten pdf");
        File saveFile = await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.FLATTEN_PDF, HttpState.done(extras: {'savedFile': saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.FLATTEN_PDF, HttpState.error(error: "Failed to flatten pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.FLATTEN_PDF, HttpState.error(error: "Failed to flatten pdf"))));
      }
    });

    on<AddBlankPagesEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ADD_BLANK_PAGES, const HttpState.loading())));
      try {
        Response<Uint8List> fileRes = await pdfService.addBlankPages(addBlankPages: event.addBlankPages, cancelToken: event.cancelToken);
        if (fileRes.data == null) throw Exception("Failed to add blank pages");
        File saveFile = await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ADD_BLANK_PAGES, HttpState.done(extras: {'savedFile': saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ADD_BLANK_PAGES, HttpState.error(error: "Failed to add blank pages"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ADD_BLANK_PAGES, HttpState.error(error: "Failed to add blank pages"))));
      }
    });

    on<StampPdfEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.STAMP_PDF, const HttpState.loading())));
      try {
        Response<Uint8List> fileRes = await pdfService.stampPdf(stampPdf: event.stampPdf, cancelToken: event.cancelToken);
        if (fileRes.data == null) throw Exception("Failed to stamp pdf");
        File saveFile = await _saveFileToProcessed(fileRes);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.STAMP_PDF, HttpState.done(extras: {'savedFile': saveFile}))));
      } on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.STAMP_PDF, HttpState.error(error: "Failed to stamp pdf"))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.STAMP_PDF, HttpState.error(error: "Failed to stamp pdf"))));
      }
    });
  }


  String _extractFilenameFromContentDisposition(String? contentDisposition) {
    if (contentDisposition != null) {
      // Extract the filename from Content-Disposition header using a regex
      RegExp regExp = RegExp(r'filename="([^"]+)"');
      var match = regExp.firstMatch(contentDisposition);
      if (match != null) {
        return match.group(1)!;
      }
    }
    return 'default_filename.pdf'; // Default filename if not found
  }

  Future<File> _saveFileToProcessed(Response<Uint8List> fileRes) async {
    if (!await StoragePermissions.requestStoragePermissions()) {
    throw Exception("Failed to save, Permission denied");
    }
    Directory directory=Directory(Constants.processedDirPath);
    if(!directory.existsSync()) await directory.create(recursive: true);
    String? contentDisposition = fileRes.headers.value('content-disposition');
    final dummyFileName='file_${DateTime.now().millisecondsSinceEpoch}.${contentDisposition?.split('.').last ?? '.pdf'}';
    String filename = contentDisposition?.split('=').last ?? dummyFileName;
    final filePath='${directory.path}/$filename';
    var file = File(filePath);
    if(file.existsSync()){
      file=File('${directory.path}/$dummyFileName');
    }
    await file.writeAsBytes(fileRes.data!);
    return file;
  }
}
