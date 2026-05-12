import 'dart:convert';
import 'package:dio/dio.dart';

class MergePdf {
  final String out_file_name;
  final List<MultipartFile> files;

  MergePdf({required this.out_file_name, required this.files}) : assert(files.isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'merge-pdf-info': MultipartFile.fromString(
        jsonEncode({'out_file_name': out_file_name}),
        contentType: DioMediaType.parse('application/json'),
      ),
      'files': files,
    };
  }
}
