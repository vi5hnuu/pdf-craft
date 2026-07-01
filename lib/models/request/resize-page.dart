import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/page-size-preset.dart';

class ResizePage {
  final PageSizePreset size;
  final MultipartFile file;

  ResizePage({required this.size, required this.file});

  Map<String, dynamic> toJson() => {
        'resize-page-info': MultipartFile.fromString(
          jsonEncode({'size': size.wire}),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
