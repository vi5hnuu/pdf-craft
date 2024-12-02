import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/direction.dart';
import 'package:pdf_craft/models/enums/quality.dart';

class PdfToJpg {
  final String out_file_name; //zip name/single image name is single=true
  final Quality quality;
  final bool single;
  final Direction direction;//if image is single -> join horizontally or vertically
  final int imageGap; // gap if single=true
  final MultipartFile file; // gap if single=true

  PdfToJpg({required this.file,required this.out_file_name,required this.quality,required this.single,required this.direction,required this.imageGap});

  Map<String,dynamic> toJson() {
    return {
      "out_file_name":out_file_name,
      "quality":quality.dpi,
      "single":single,
      "direction":direction.direction,
      "imageGap":imageGap,
      "file":file,
    };
  }
}
