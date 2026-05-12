import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/position.dart';

class WatermarkPdf {
  final String outFileName;
  final String text;
  final int fontSize;
  final ColorInfo? color;
  final double opacity;
  final double angle;
  final WatermarkPosition verticalPosition;
  final WatermarkPosition horizontalPosition;
  final int fromPage;
  final int? toPage;
  final MultipartFile file;

  WatermarkPdf({
    required this.outFileName,
    this.text = 'CONFIDENTIAL',
    this.fontSize = 48,
    this.color,
    this.opacity = 0.3,
    this.angle = 45.0,
    this.verticalPosition = WatermarkPosition.CENTER,
    this.horizontalPosition = WatermarkPosition.CENTER,
    this.fromPage = 0,
    this.toPage,
    required this.file,
  });

  Map<String, dynamic> toJson() {
    return {
      'watermark-pdf-info': MultipartFile.fromString(
        jsonEncode({
          'out_file_name': outFileName,
          'text': text,
          'font_size': fontSize,
          if (color != null) 'color': color!.toJson(),
          'opacity': opacity,
          'angle': angle,
          'vertical_position': verticalPosition.name,
          'horizontal_position': horizontalPosition.name,
          'from_page': fromPage,
          if (toPage != null) 'to_page': toPage,
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
