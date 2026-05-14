import 'dart:convert';
import 'package:dio/dio.dart';

enum ImageFilterType { grayscale, sepia, sharpen, brightness, contrast, vintage }

class FilterImage {
  final String? outFileName;
  final ImageFilterType filterType;
  final double intensity; // 0.0–2.0
  final MultipartFile file;

  FilterImage({
    this.outFileName,
    this.filterType = ImageFilterType.grayscale,
    this.intensity = 1.0,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'filter-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'filter_type': filterType.name.toUpperCase(),
            'intensity': intensity,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
