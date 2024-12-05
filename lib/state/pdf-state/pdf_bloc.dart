import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/WithHttpState.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/models/request/merge-pdf.dart';
import 'package:pdf_craft/models/request/page-numbers.dart';
import 'package:pdf_craft/models/request/pdf-to-jpg.dart';
import 'package:pdf_craft/models/request/protect-pdf.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/models/request/unlock-pdf.dart';
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
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF, HttpState.error(error:"Failed to reorder pages."))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REORDER_PDF, HttpState.error(error: "Failed to reorder pages."))));
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
        await pdfService.rotatePdf(rotatePdf: event.rotatePdf,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.ROTATE_PDF,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ROTATE_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.ROTATE_PDF, HttpState.error(error: e.toString()))));
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
    if (!await StoragePermissions.requestPermissions()) {
    throw Exception("Failed to save, Permission denied");
    }
    Directory directory=Directory(Constants.processedDirPath);
    if(!directory.existsSync()) await directory.create(recursive: true);
    String? contentDisposition = fileRes.headers.value('content-disposition');
    String filename = contentDisposition?.split('=').last ?? 'file_${DateTime.now().millisecond}.pdf';
    final filePath='${directory.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(fileRes.data!);
    return file;
  }
}
