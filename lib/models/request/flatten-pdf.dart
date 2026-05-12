import 'dart:convert';
import 'package:dio/dio.dart';

class FlattenPdf {
  final String? outFileName;
  final MultipartFile file;

  FlattenPdf({this.outFileName, required this.file});

  Map<String, dynamic> toJson() => {
        'flatten-pdf-info': MultipartFile.fromString(
          jsonEncode({'out_file_name': outFileName}),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
