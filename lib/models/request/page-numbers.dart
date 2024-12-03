import 'package:dio/dio.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/font.dart';
import 'package:pdf_craft/models/enums/page-no-type.dart';
import 'package:pdf_craft/models/enums/position-info.dart';
import 'package:pdf_craft/models/padding-info.dart';

class PageNumbers {
  final String out_file_name;
  final PageNoType page_no_type;
  final int? size;//14 default
  final ColorInfo fill_color;
  final PositionInfo vertical_position;
  final PositionInfo horizontal_position;
  final Padding? padding; //default 0
  final int? from_page; //default 0
  final int? to_page; //default lengthOfPDF
  final FontName font_name;
  final MultipartFile file;

  PageNumbers({
    required this.out_file_name,
    required this.page_no_type,
    required this.size,
    required this.fill_color,
    required this.vertical_position,
    required this.horizontal_position,
    required this.padding,
    required this.from_page,
    required this.to_page,
    required this.file,
    required this.font_name});

  Map<String,dynamic> toJson() {
    return {
      "out_file_name":out_file_name,
      "page_no_type":page_no_type,
      "size":size,
      "fill_color":fill_color,
      "vertical_position":vertical_position,
      "horizontal_position":horizontal_position,
      "padding":padding,
      "from_page":from_page,
      "to_page":to_page,
      "font_name":font_name,
      "file":file,
    };
  }
}
