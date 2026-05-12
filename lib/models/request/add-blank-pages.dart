import 'dart:convert';
import 'package:dio/dio.dart';

class AddBlankPages {
  final String? outFileName;
  final List<int> positions; // 0-indexed positions to insert blank pages
  final double? pageWidth;
  final double? pageHeight;
  final MultipartFile file;

  AddBlankPages({
    this.outFileName,
    required this.positions,
    this.pageWidth,
    this.pageHeight,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'add-blank-pages-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'positions': positions,
            if (pageWidth != null) 'page_width': pageWidth,
            if (pageHeight != null) 'page_height': pageHeight,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
