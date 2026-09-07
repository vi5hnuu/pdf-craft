import 'dart:convert';

import 'package:dio/dio.dart';

class CropPdf {
  final String outFileName;
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
          if (pages.isNotEmpty) 'pages': pages,
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
