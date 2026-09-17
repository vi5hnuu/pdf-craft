import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/split_type.dart';

class SplitPdf{
  final String outFileName;
  final SplitType type;
  final int? fixed;
  final List<RangeModel>? ranges;
  final MultipartFile file;

  SplitPdf({required this.outFileName,required this.type,required this.fixed,required this.ranges,required this.file});

  Map<String,dynamic> toJson() {
    return {
      "split-pdf-info":MultipartFile.fromString(jsonEncode({
        "out_file_name":outFileName,
        "type":type.type,
        "fixed":fixed,
        "ranges":ranges,
      }),contentType: DioMediaType.parse("application/json")),
      "file":file,
    };
  }
}


class RangeModel {
  final int from;
  final int to;

  RangeModel({required this.from,required this.to});

  Map<String,dynamic> toJson() {
    return {
      "from":from,
      "to":to
    };
  }
}