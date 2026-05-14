import 'dart:convert';
import 'package:dio/dio.dart';

class DuplicatePages {
  final String? outFileName;
  final List<int> pages; // 0-indexed
  final int count;       // copies of each selected page to insert (default 1)
  final MultipartFile file;

  DuplicatePages({
    this.outFileName,
    required this.pages,
    this.count = 1,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'duplicate-pages-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'pages': pages,
            'count': count,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
