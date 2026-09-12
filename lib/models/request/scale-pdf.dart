import 'dart:convert';
import 'package:dio/dio.dart';

class ScalePdf {
  final double scale; // e.g. 0.5 = half, 2.0 = double
  /// 0-indexed pages to apply this to. Empty means the whole document, which is what this
  /// tool did before it could be narrowed.
  final List<int> pages;
  final MultipartFile file;

  ScalePdf({required this.scale, this.pages = const [], required this.file});

  Map<String, dynamic> toJson() => {
        'scale-pdf-info': MultipartFile.fromString(
          jsonEncode({
            'scale': scale,
            if (pages.isNotEmpty) 'pages': pages,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
