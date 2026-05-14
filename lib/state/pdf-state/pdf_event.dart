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

class GetMetadataEvent extends PdfEvent {
  final GetMetadata getMetadata;
  const GetMetadataEvent({required this.getMetadata, super.cancelToken});
}

class EditMetadataEvent extends PdfEvent {
  final EditMetadata editMetadata;
  const EditMetadataEvent({required this.editMetadata, super.cancelToken});
}

class HeaderFooterEvent extends PdfEvent {
  final HeaderFooter headerFooter;
  const HeaderFooterEvent({required this.headerFooter, super.cancelToken});
}

class RepairPdfEvent extends PdfEvent {
  final RepairPdf repairPdf;
  const RepairPdfEvent({required this.repairPdf, super.cancelToken});
}

class FlattenPdfEvent extends PdfEvent {
  final FlattenPdf flattenPdf;
  const FlattenPdfEvent({required this.flattenPdf, super.cancelToken});
}

class AddBlankPagesEvent extends PdfEvent {
  final AddBlankPages addBlankPages;
  const AddBlankPagesEvent({required this.addBlankPages, super.cancelToken});
}

class StampPdfEvent extends PdfEvent {
  final StampPdf stampPdf;
  const StampPdfEvent({required this.stampPdf, super.cancelToken});
}

class PlaceImageEvent extends PdfEvent {
  final PlaceImage placeImage;
  const PlaceImageEvent({required this.placeImage, super.cancelToken});
}

class CompressImageEvent extends PdfEvent {
  final CompressImage compressImage;
  const CompressImageEvent({required this.compressImage, super.cancelToken});
}

class ConvertToJpgEvent extends PdfEvent {
  final ConvertToJpg convertToJpg;
  const ConvertToJpgEvent({required this.convertToJpg, super.cancelToken});
}

class ConvertFromJpgEvent extends PdfEvent {
  final ConvertFromJpg convertFromJpg;
  const ConvertFromJpgEvent({required this.convertFromJpg, super.cancelToken});
}

class ResizeImageEvent extends PdfEvent {
  final ResizeImage resizeImage;
  const ResizeImageEvent({required this.resizeImage, super.cancelToken});
}

class PdfToOfficeEvent extends PdfEvent {
  final PdfToOffice pdfToOffice;
  const PdfToOfficeEvent({required this.pdfToOffice, super.cancelToken});
}

class RedactPdfEvent extends PdfEvent {
  final RedactPdf redactPdf;
  const RedactPdfEvent({required this.redactPdf, super.cancelToken});
}

class DuplicatePagesEvent extends PdfEvent {
  final DuplicatePages duplicatePages;
  const DuplicatePagesEvent({required this.duplicatePages, super.cancelToken});
}

class GetBookmarksEvent extends PdfEvent {
  final GetBookmarks getBookmarks;
  const GetBookmarksEvent({required this.getBookmarks, super.cancelToken});
}

class EditBookmarksEvent extends PdfEvent {
  final EditBookmarks editBookmarks;
  const EditBookmarksEvent({required this.editBookmarks, super.cancelToken});
}

class FilterImageEvent extends PdfEvent {
  final FilterImage filterImage;
  const FilterImageEvent({required this.filterImage, super.cancelToken});
}