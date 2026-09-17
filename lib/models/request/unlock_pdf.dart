import 'dart:convert';

import 'package:dio/dio.dart';

class UnProtectPdf {
  final String outFileName;
  final String password;
  final MultipartFile file;

  UnProtectPdf({required this.outFileName,required this.password,required this.file});

  Map<String,dynamic> toJson() {
    return {
      "unprotect-pdf-info":MultipartFile.fromString(jsonEncode({
        "out_file_name":outFileName,
        "password":password,}),
          contentType: DioMediaType.parse("application/json")),
      "file":file,
    };
  }
}
