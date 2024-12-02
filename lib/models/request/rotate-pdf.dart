import 'dart:io';

import 'package:dio/dio.dart';

class RotatePdf {
  final String out_file_name;
  final int file_angle; // angle at which all pages will be rotated
  final Map<int,int> page_angles; // if a page do not have angle file angle is used else no rotation [0 index]
  final bool maintain_ratio;//default true
  final MultipartFile file;//default true

  RotatePdf({required this.out_file_name,
    required this.file_angle,
    required this.page_angles,
    required this.file,
    required this.maintain_ratio});

  Map<String,dynamic> toJson() {
    return {
      "out_file_name":out_file_name,
      "file_angle":file_angle,
      "page_angles":page_angles,
      "maintain_ratio":maintain_ratio,
      "file":file,
    };
  }
}