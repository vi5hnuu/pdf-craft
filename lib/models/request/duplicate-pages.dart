import 'dart:convert';
import 'package:dio/dio.dart';

class DuplicatePages {
  final String? outFileName;
  // 0-indexed page number -> number of extra copies to insert after that page.
  final Map<int, int> pageCounts;
  final MultipartFile file;

  DuplicatePages({
    this.outFileName,
    required this.pageCounts,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'duplicate-pages-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            // JSON object keys must be strings; backend reads them as ints.
            'page_counts': pageCounts.map((k, v) => MapEntry(k.toString(), v)),
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
