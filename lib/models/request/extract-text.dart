import 'dart:convert';

import 'package:dio/dio.dart';

class ExtractText {
  final String outFileName;
  /// 0-indexed pages to apply this to. Empty means the whole document, which is what this
  /// tool did before it could be narrowed.
  final List<int> pages;
  final MultipartFile file;

  ExtractText({required this.outFileName, this.pages = const [], required this.file});

  Map<String, dynamic> toJson() {
    return {
      'extract-text-info': MultipartFile.fromString(
        jsonEncode({
          'out_file_name': outFileName,
          if (pages.isNotEmpty) 'pages': pages,
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
