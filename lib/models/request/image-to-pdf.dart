import 'dart:convert';
import 'package:dio/dio.dart';

/// Builds a PDF from images, one image per page.
///
/// Pages used to be sized one point per pixel, which turned a phone photo into a page several
/// feet across and gave a mixed set of images a different page size each. [pageSize] defaults to
/// A4 with the image fitted inside it; `MATCH_IMAGE` restores the old behaviour.
class ImageToPdf {
  final String out_file_name;

  /// One of `A4`, `LETTER`, `LEGAL`, `MATCH_IMAGE`.
  final String pageSize;

  /// One of `AUTO`, `PORTRAIT`, `LANDSCAPE`. `AUTO` follows each image's own orientation.
  final String orientation;

  /// White space around the image, in points (72 = 1 inch).
  final double marginPt;

  final List<MultipartFile> files;

  ImageToPdf({
    required this.out_file_name,
    this.pageSize = 'A4',
    this.orientation = 'AUTO',
    this.marginPt = 0,
    required this.files,
  });

  Map<String, dynamic> toJson() {
    return {
      'image-to-pdf-info': MultipartFile.fromString(
        jsonEncode({
          'out_file_name': out_file_name,
          'page_size': pageSize,
          'orientation': orientation,
          'margin_pt': marginPt,
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'files': files,
    };
  }
}
