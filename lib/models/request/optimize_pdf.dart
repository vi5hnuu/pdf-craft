import 'dart:convert';
import 'package:dio/dio.dart';

class OptimizePdf {
  final String? outFileName;
  final MultipartFile file;

  OptimizePdf({this.outFileName, required this.file});

  Map<String, dynamic> toJson() => {
        'optimize-pdf-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
