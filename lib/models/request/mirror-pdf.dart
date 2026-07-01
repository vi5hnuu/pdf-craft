import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/mirror-direction.dart';

class MirrorPdf {
  final MirrorDirection direction;
  final List<int>? pages; // 0-indexed; null/empty = all
  final MultipartFile file;

  MirrorPdf({required this.direction, this.pages, required this.file});

  Map<String, dynamic> toJson() => {
        'mirror-pdf-info': MultipartFile.fromString(
          jsonEncode({
            'direction': direction.wire,
            if (pages != null && pages!.isNotEmpty) 'pages': pages,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
