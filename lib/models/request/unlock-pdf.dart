import 'dart:convert';

import 'package:dio/dio.dart';

class UnProtectPdf {
  final String out_file_name;
  final String password;
  final MultipartFile file;

  UnProtectPdf({required this.out_file_name,required this.password,required this.file});

  Map<String,dynamic> toJson() {
    return {
      "unprotect-pdf-info":MultipartFile.fromString(jsonEncode({
        "out_file_name":out_file_name,
        "password":password,}),
          contentType: DioMediaType.parse("application/json")),
      "file":file,
    };
  }
}
