import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/compression-level.dart';

class CompressPdf {
  final String outFileName;
  final CompressionLevel level;
  final MultipartFile file;

  CompressPdf({required this.outFileName, required this.level, required this.file});

  Map<String, dynamic> toJson() {
    return {
      'compress-pdf-info': MultipartFile.fromString(
        jsonEncode({'out_file_name': outFileName, 'level': level.name}),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
