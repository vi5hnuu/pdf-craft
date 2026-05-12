import 'dart:convert';

import 'package:dio/dio.dart';

class GrayscalePdf {
  final String outFileName;
  final MultipartFile file;

  GrayscalePdf({required this.outFileName, required this.file});

  Map<String, dynamic> toJson() {
    return {
      'grayscale-pdf-info': MultipartFile.fromString(
        jsonEncode({'out_file_name': outFileName}),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
