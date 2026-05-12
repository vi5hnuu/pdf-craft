import 'dart:convert';

import 'package:dio/dio.dart';

class ExtractText {
  final String outFileName;
  final MultipartFile file;

  ExtractText({required this.outFileName, required this.file});

  Map<String, dynamic> toJson() {
    return {
      'extract-text-info': MultipartFile.fromString(
        jsonEncode({'out_file_name': outFileName}),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
