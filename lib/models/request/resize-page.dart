import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/page-size-preset.dart';

class ResizePage {
  final PageSizePreset size;
  /// 0-indexed pages to apply this to. Empty means the whole document, which is what this
  /// tool did before it could be narrowed.
  final List<int> pages;
  final MultipartFile file;

  ResizePage({required this.size, this.pages = const [], required this.file});

  Map<String, dynamic> toJson() => {
        'resize-page-info': MultipartFile.fromString(
          jsonEncode({
            'size': size.wire,
            if (pages.isNotEmpty) 'pages': pages,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
