import 'dart:convert';
import 'package:dio/dio.dart';

class ImageToPdf {
  final String out_file_name;
  final List<MultipartFile> files;

  ImageToPdf({required this.out_file_name, required this.files});

  Map<String, dynamic> toJson() {
    return {
      'image-to-pdf-info': MultipartFile.fromString(
        jsonEncode({'out_file_name': out_file_name}),
        contentType: DioMediaType.parse('application/json'),
      ),
      'files': files,
    };
  }
}
