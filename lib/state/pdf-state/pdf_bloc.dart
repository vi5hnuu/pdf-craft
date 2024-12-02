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
import 'package:pdf_craft/utils/httpStates.dart';
import '../../models/HttpState.dart';
part 'pdf_event.dart';
part 'pdf_state.dart';

class PdfBloc extends Bloc<PdfEvent, PdfState> {
  PdfBloc({required PdfService pdfService}) : super(PdfState.initial()) {

    on<MergePdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MERGE_PDF,const HttpState.loading())));
      try {
        await pdfService.mergePdf(mergePdf: event.mergePdf,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.MERGE_PDF,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MERGE_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MERGE_PDF, HttpState.error(error: e.toString()))));
      }
    });

    on<ReorderPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REORDER_PDF,const HttpState.loading())));
      try {
        await pdfService.reorderPdf(reorderPdf: event.reorderPdf,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.REORDER_PDF,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REORDER_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.REORDER_PDF, HttpState.error(error: e.toString()))));
      }
    });

    on<SplitPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.SPLIT_PDF,const HttpState.loading())));
      try {
        await pdfService.splitPdf(splitPdf: event.splitPdf,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.SPLIT_PDF,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.SPLIT_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.SPLIT_PDF, HttpState.error(error: e.toString()))));
      }
    });

    on<PdfToJpgEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PDF_TO_JPG,const HttpState.loading())));
      try {
        await pdfService.pdfToJpg(pdfToJpg: event.pdfToJpg,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.PDF_TO_JPG,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PDF_TO_JPG, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PDF_TO_JPG, HttpState.error(error: e.toString()))));
      }
    });

    on<ImageToPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF,const HttpState.loading())));
      try {
        await pdfService.imageToPdf(imageToPdf: event.imageToPdf,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.IMAGE_TO_PDF, HttpState.error(error: e.toString()))));
      }
    });

    on<PageNumbersEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS,const HttpState.loading())));
      try {
        await pdfService.pageNumbers(pageNumber: event.pageNumber,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PAGE_NUMBERS, HttpState.error(error: e.toString()))));
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
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.UNLOCK_PDF,const HttpState.loading())));
      try {
        await pdfService.unprotectPdf(unlockOdf: event.unlockPdf,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.UNLOCK_PDF,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.UNLOCK_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.UNLOCK_PDF, HttpState.error(error: e.toString()))));
      }
    });

    on<ProtectPdfEvent>((event,emit)async{
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PROTECT_PDF,const HttpState.loading())));
      try {
        await pdfService.protectpdf(protectPdf: event.protectPdf,cancelToken: event.cancelToken);
        emit(state.copyWith(httpStates:state.httpStates.clone()..put(HttpStates.PROTECT_PDF,const HttpState.done())));
      }  on DioException catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PROTECT_PDF, HttpState.error(error:e.message))));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.PROTECT_PDF, HttpState.error(error: e.toString()))));
      }
    });
  }
}
