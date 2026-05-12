import 'dart:convert';
import 'package:dio/dio.dart';

class StampPdf {
  final String? outFileName;
  final double opacity;
  final int fromPage;
  final int? toPage;
  final MultipartFile file;  // the PDF
  final MultipartFile stamp; // the stamp image

  StampPdf({
    this.outFileName,
    this.opacity = 0.5,
    this.fromPage = 0,
    this.toPage,
    required this.file,
    required this.stamp,
  });

  Map<String, dynamic> toJson() => {
        'stamp-pdf-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'opacity': opacity,
            'from_page': fromPage,
            if (toPage != null) 'to_page': toPage,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
        'stamp': stamp,
      };
}
