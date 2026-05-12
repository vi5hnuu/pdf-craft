part of 'pdf_bloc.dart';

@immutable
abstract class PdfEvent {
  final CancelToken? cancelToken;
  const PdfEvent({this.cancelToken});
}



class MergePdfEvent extends PdfEvent{
  final MergePdf mergePdf;
  const MergePdfEvent({required this.mergePdf, super.cancelToken});
}

class ReorderPdfEvent extends PdfEvent{
  final ReorderPdf reorderPdf;
  const ReorderPdfEvent({required this.reorderPdf, super.cancelToken});
}

class SplitPdfEvent extends PdfEvent{
  final SplitPdf splitPdf;
  const SplitPdfEvent({required this.splitPdf, super.cancelToken});
}

class PdfToJpgEvent extends PdfEvent{
  final PdfToJpg pdfToJpg;
  const PdfToJpgEvent({required this.pdfToJpg, super.cancelToken});
}

class ImageToPdfEvent extends PdfEvent{
  final ImageToPdf imageToPdf;
  const ImageToPdfEvent({required this.imageToPdf, super.cancelToken});
}

class PageNumbersEvent extends PdfEvent{
  final PageNumbers pageNumber;
  const PageNumbersEvent({required this.pageNumber, super.cancelToken});
}

class RotatePdfEvent extends PdfEvent{
  final RotatePdf rotatePdf;
  const RotatePdfEvent({required this.rotatePdf, super.cancelToken});
}

class UnprotectPdfEvent extends PdfEvent{
  final UnProtectPdf unlockPdf;
  const UnprotectPdfEvent({required this.unlockPdf, super.cancelToken});
}

class ProtectPdfEvent extends PdfEvent{
  final ProtectPdf protectPdf;
  const ProtectPdfEvent({required this.protectPdf, CancelToken? cancelToken});
}

class CompressPdfEvent extends PdfEvent{
  final CompressPdf compressPdf;
  const CompressPdfEvent({required this.compressPdf, super.cancelToken});
}

class WatermarkPdfEvent extends PdfEvent{
  final WatermarkPdf watermarkPdf;
  const WatermarkPdfEvent({required this.watermarkPdf, super.cancelToken});
}

class ExtractTextEvent extends PdfEvent{
  final ExtractText extractText;
  const ExtractTextEvent({required this.extractText, super.cancelToken});
}

class GrayscalePdfEvent extends PdfEvent{
  final GrayscalePdf grayscalePdf;
  const GrayscalePdfEvent({required this.grayscalePdf, super.cancelToken});
}

class CropPdfEvent extends PdfEvent{
  final CropPdf cropPdf;
  const CropPdfEvent({required this.cropPdf, super.cancelToken});
}