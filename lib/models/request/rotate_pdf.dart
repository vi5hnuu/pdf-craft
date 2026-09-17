import 'dart:convert';

import 'package:dio/dio.dart';

class RotatePdf {
  final String outFileName;
  final int? fileAngle; // angle at which all pages will be rotated
  final Map<int,int> pageAngles; // if a page do not have angle, file angle is used else no rotation [0 index]
  final bool maintainRatio;//default true
  final MultipartFile file;

  RotatePdf({required this.outFileName,
    required this.fileAngle,
    required this.pageAngles,
    required this.file,
    required this.maintainRatio});

  Map<String,dynamic> toJson() {
    return {
      "rotate-pdf-info":MultipartFile.fromString(jsonEncode({
        "out_file_name":outFileName,
        "file_angle":fileAngle,
        "page_angles":Map.fromEntries(pageAngles.entries.map((entry)=>MapEntry(entry.key.toString(), entry.value))),
        "maintain_ratio":maintainRatio,
      }),contentType: DioMediaType.parse("application/json")),
      "file":file,
    };
  }
}