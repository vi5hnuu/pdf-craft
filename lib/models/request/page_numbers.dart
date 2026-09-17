import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/color_info.dart';
import 'package:pdf_craft/models/enums/font.dart';
import 'package:pdf_craft/models/enums/page_no_type.dart';
import 'package:pdf_craft/models/enums/position_info.dart';
import 'package:pdf_craft/models/padding_info.dart';

class PageNumbers {
  final String outFileName;
  final PageNoType pageNoType;
  final int? size;//14 default
  final ColorInfo fillColor;
  final PositionInfo verticalPosition;
  final PositionInfo horizontalPosition;
  final PaddingInfo? padding; //default 0
  final int? fromPage; //default 0
  final int? toPage; //default lengthOfPDF
  final FontName fontName;
  final MultipartFile file;

  PageNumbers({
    required this.outFileName,
    required this.pageNoType,
    required this.size,
    required this.fillColor,
    required this.verticalPosition,
    required this.horizontalPosition,
    required this.padding,
    required this.fromPage,
    required this.toPage,
    required this.file,
    required this.fontName});

  Map<String,dynamic> toJson() {
    return {
      "page-numbers-info":MultipartFile.fromString(
        jsonEncode({
          "out_file_name":outFileName,
          "page_no_type":pageNoType.type,
          "size":size,
          "fill_color":fillColor.toJson(),
          "vertical_position":verticalPosition.position,
          "horizontal_position":horizontalPosition.position,
          "padding":padding?.toJson(),
          "from_page":fromPage,
          "to_page":toPage,
          "font_name":fontName.value,
        }),
        contentType: DioMediaType.parse("application/json"),
      ),
      "file":file,
    };
  }
}
