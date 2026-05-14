import 'dart:convert';
import 'package:dio/dio.dart';

class RedactRegion {
  final int page;    // 0-indexed
  final double x;
  final double y;    // top-left origin (backend handles Y-inversion)
  final double width;
  final double height;

  const RedactRegion({
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'page': page,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

class RedactPdf {
  final String? outFileName;
  final List<RedactRegion> regions;
  final MultipartFile file;

  RedactPdf({this.outFileName, required this.regions, required this.file});

  Map<String, dynamic> toJson() => {
        'redact-pdf-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'regions': regions.map((r) => r.toJson()).toList(),
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
