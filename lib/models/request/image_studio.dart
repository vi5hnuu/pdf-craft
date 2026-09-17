import 'dart:convert';
import 'package:dio/dio.dart';

enum ImageStudioOp { compress, convertToJpg, convertFromJpg, resize, filter }

class CompressImage {
  final String? outFileName;
  final int quality; // 1–100
  final MultipartFile file;

  CompressImage({this.outFileName, this.quality = 75, required this.file});

  Map<String, dynamic> toJson() => {
        'compress-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'quality': quality,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}

class ConvertToJpg {
  final String? outFileName;
  final int quality; // 1–100
  final MultipartFile file;

  ConvertToJpg({this.outFileName, this.quality = 90, required this.file});

  Map<String, dynamic> toJson() => {
        'convert-to-jpg-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'quality': quality,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}

class ConvertFromJpg {
  final String? outFileName;
  final String format; // "PNG" or "BMP"
  final MultipartFile file;

  ConvertFromJpg({this.outFileName, this.format = 'PNG', required this.file});

  Map<String, dynamic> toJson() => {
        'convert-from-jpg-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'format': format,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}

class ResizeImage {
  final String? outFileName;
  final int? width;
  final int? height;
  final bool maintainAspectRatio;
  final MultipartFile file;

  ResizeImage({
    this.outFileName,
    this.width,
    this.height,
    this.maintainAspectRatio = true,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'resize-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            if (width != null) 'width': width,
            if (height != null) 'height': height,
            'maintain_aspect_ratio': maintainAspectRatio,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
