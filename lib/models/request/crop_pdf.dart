import 'dart:convert';

import 'package:dio/dio.dart';

/// Trims the visible area of a PDF.
///
/// The area to keep travels as a fraction of each page. Margins in points can only be measured
/// against the page shown in the editor, so on a document whose pages are not all the same size
/// the crop was right there and wrong everywhere else — and where the margins exceeded a smaller
/// page it was skipped there in silence, so the file came back cropped on page one and untouched
/// after it.
class CropPdf {
  final String outFileName;

  /// The area to keep, as a fraction of each page (0.0-1.0), origin top-left.
  final double keepXFrac;
  final double keepYFrac;
  final double keepWidthFrac;
  final double keepHeightFrac;

  /// Point margins, still sent so an older server keeps working.
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  /// 0-indexed pages to apply this to. Empty means the whole document, which is what this
  /// tool did before it could be narrowed.
  final List<int> pages;
  final MultipartFile file;

  CropPdf({
    required this.outFileName,
    required this.keepXFrac,
    required this.keepYFrac,
    required this.keepWidthFrac,
    required this.keepHeightFrac,
    this.marginTop = 0,
    this.marginBottom = 0,
    this.marginLeft = 0,
    this.marginRight = 0,
    this.pages = const [],
    required this.file,
  });

  Map<String, dynamic> toJson() {
    return {
      'crop-pdf-info': MultipartFile.fromString(
        jsonEncode({
          'out_file_name': outFileName,
          'margin_top': marginTop,
          'margin_bottom': marginBottom,
          'margin_left': marginLeft,
          'margin_right': marginRight,
          'keep_x_frac': keepXFrac,
          'keep_y_frac': keepYFrac,
          'keep_width_frac': keepWidthFrac,
          'keep_height_frac': keepHeightFrac,
          if (pages.isNotEmpty) 'pages': pages,
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
