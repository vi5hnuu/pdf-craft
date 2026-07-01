import 'dart:convert';
import 'package:dio/dio.dart';

class ScalePdf {
  final double scale; // e.g. 0.5 = half, 2.0 = double
  final MultipartFile file;

  ScalePdf({required this.scale, required this.file});

  Map<String, dynamic> toJson() => {
        'scale-pdf-info': MultipartFile.fromString(
          jsonEncode({'scale': scale}),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
