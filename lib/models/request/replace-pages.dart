import 'dart:convert';
import 'package:dio/dio.dart';

class ReplacePages {
  final String? outFileName;
  final int from; // 1-indexed inclusive
  final int to;   // 1-indexed inclusive
  final MultipartFile file;        // base PDF
  final MultipartFile replacement; // PDF whose pages replace the range

  ReplacePages({
    this.outFileName,
    required this.from,
    required this.to,
    required this.file,
    required this.replacement,
  });

  Map<String, dynamic> toJson() => {
        'replace-pages-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'from': from,
            'to': to,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
        'replacement': replacement,
      };
}
