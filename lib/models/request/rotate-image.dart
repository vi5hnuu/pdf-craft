import 'dart:convert';
import 'package:dio/dio.dart';

class RotateImage {
  final String? outFileName;
  final int angle; // 0 / 90 / 180 / 270
  final MultipartFile file;

  RotateImage({this.outFileName, required this.angle, required this.file});

  Map<String, dynamic> toJson() => {
        'rotate-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'angle': angle,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
