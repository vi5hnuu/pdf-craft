import 'dart:convert';
import 'package:dio/dio.dart';

class InsertPdf {
  final String? outFileName;
  final int afterPage; // 0-indexed page of the base to insert after (-1 = start)
  final MultipartFile file;   // base PDF
  final MultipartFile insert; // PDF to insert

  InsertPdf({this.outFileName, required this.afterPage, required this.file, required this.insert});

  Map<String, dynamic> toJson() => {
        'insert-pdf-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'after_page': afterPage,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
        'insert': insert,
      };
}
