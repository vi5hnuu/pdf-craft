import 'dart:convert';

import 'package:dio/dio.dart';

class RotatePdf {
  final String out_file_name;
  final int? file_angle; // angle at which all pages will be rotated
  final Map<int,int> page_angles; // if a page do not have angle, file angle is used else no rotation [0 index]
  final bool maintain_ratio;//default true
  final MultipartFile file;

  RotatePdf({required this.out_file_name,
    required this.file_angle,
    required this.page_angles,
    required this.file,
    required this.maintain_ratio});

  Map<String,dynamic> toJson() {
    return {
      "rotate-pdf-info":MultipartFile.fromString(jsonEncode({
        "out_file_name":out_file_name,
        "file_angle":file_angle,
        "page_angles":Map.fromEntries(page_angles.entries.map((entry)=>MapEntry(entry.key.toString(), entry.value))),
        "maintain_ratio":maintain_ratio,
      }),contentType: DioMediaType.parse("application/json")),
      "file":file,
    };
  }
}