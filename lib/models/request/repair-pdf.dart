import 'dart:convert';
import 'package:dio/dio.dart';

class RepairPdf {
  final String? outFileName;
  final MultipartFile file;

  RepairPdf({this.outFileName, required this.file});

  Map<String, dynamic> toJson() => {
        'repair-pdf-info': MultipartFile.fromString(
          jsonEncode({'out_file_name': outFileName}),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
