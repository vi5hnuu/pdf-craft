import 'dart:convert';
import 'package:dio/dio.dart';

class PlaceImage {
  final String? outFileName;
  final int page;       // 0-indexed
  final double xFrac;   // left edge as fraction of page width (0.0–1.0)
  final double yFrac;   // top edge as fraction of page height (0.0–1.0)
  final double widthFrac;
  final double heightFrac;
  final MultipartFile file;  // the PDF
  final MultipartFile image; // the image to place

  PlaceImage({
    this.outFileName,
    required this.page,
    required this.xFrac,
    required this.yFrac,
    required this.widthFrac,
    required this.heightFrac,
    required this.file,
    required this.image,
  });

  Map<String, dynamic> toJson() => {
        'place-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'page': page,
            'x_frac': xFrac,
            'y_frac': yFrac,
            'width_frac': widthFrac,
            'height_frac': heightFrac,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
        'image': image,
      };
}
