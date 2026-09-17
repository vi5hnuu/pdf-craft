import 'dart:convert';
import 'package:dio/dio.dart';

class BorderImage {
  final String? outFileName;
  final int width; // border thickness in px
  final int r, g, b;
  final MultipartFile file;

  BorderImage({
    this.outFileName,
    required this.width,
    required this.r,
    required this.g,
    required this.b,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'border-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'width': width,
            'r': r,
            'g': g,
            'b': b,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
