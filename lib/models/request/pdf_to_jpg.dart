import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/direction.dart';
import 'package:pdf_craft/models/enums/quality.dart';

class PdfToJpg {

  final MultipartFile file;
  final PdfToJpgMeta meta;

  PdfToJpg({required this.file,required this.meta});

  Map<String,dynamic> toJson() {
    return {
      "file":file,
      "pdf-to-jpg-info": MultipartFile.fromString(
        jsonEncode(meta.toJson()),
        contentType: DioMediaType.parse("application/json"),
      ),
    };
  }
}


class PdfToJpgMeta{
  final String outFileName; //zip name/single image name is single=true
  final Quality quality;
  final bool single;
  final Direction? direction;//if image is single -> join horizontally or vertically
  final int? imageGap; // gap if single=true

  /// 0-indexed pages to apply this to. Empty means the whole document, which is what this
  /// tool did before it could be narrowed.
  final List<int> pages;

  PdfToJpgMeta({required this.outFileName,required this.quality,required this.single,required this.direction,this.imageGap,this.pages = const []}){
    if(single && (direction==null || imageGap==null)) throw Exception("for single image direction/imageGap cannot be null");
    if(!single && (direction!=null || imageGap!=null)) throw Exception("for multiple images direction/imageGap should be null");
  }

  Map<String,dynamic> toJson() {
    return {
      "out_file_name":outFileName,
      // The name, not the DPI: the API binds this to an enum and Jackson reads an integer as
      // an ordinal, so 72/150/300 were all out of range and every request was a 400 before
      // the controller ran. The DPI is still what the UI works in.
      "quality":quality.name,
      "single":single,
      "direction":direction?.direction,
      "image_gap":imageGap,
      if (pages.isNotEmpty) "pages": pages,
    };
  }
}