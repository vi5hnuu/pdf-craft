import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/font-name.dart';

class HeaderFooter {
  final String? outFileName;
  final String? headerText;
  final String? footerText;
  final int fontSize;
  final ColorInfo? color;
  final PdfFontName fontName;
  final int fromPage;
  final int? toPage;
  final double topPadding;
  final double bottomPadding;
  final MultipartFile file;

  HeaderFooter({
    this.outFileName,
    this.headerText,
    this.footerText,
    this.fontSize = 12,
    this.color,
    this.fontName = PdfFontName.HELVETICA,
    this.fromPage = 0,
    this.toPage,
    this.topPadding = 20,
    this.bottomPadding = 20,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'header-footer-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            if (headerText != null) 'header_text': headerText,
            if (footerText != null) 'footer_text': footerText,
            'font_size': fontSize,
            if (color != null) 'color': color!.toJson(),
            'font_name': fontName.name,
            'from_page': fromPage,
            if (toPage != null) 'to_page': toPage,
            'top_padding': topPadding,
            'bottom_padding': bottomPadding,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
