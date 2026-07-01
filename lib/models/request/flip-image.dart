import 'dart:convert';
import 'package:dio/dio.dart';

class FlipImage {
  final String? outFileName;
  final String direction; // HORIZONTAL / VERTICAL
  final MultipartFile file;

  FlipImage({this.outFileName, required this.direction, required this.file});

  Map<String, dynamic> toJson() => {
        'flip-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'direction': direction,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
