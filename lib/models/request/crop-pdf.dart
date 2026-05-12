import 'dart:convert';

import 'package:dio/dio.dart';

class CropPdf {
  final String outFileName;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final MultipartFile file;

  CropPdf({
    required this.outFileName,
    this.marginTop = 0,
    this.marginBottom = 0,
    this.marginLeft = 0,
    this.marginRight = 0,
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
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
