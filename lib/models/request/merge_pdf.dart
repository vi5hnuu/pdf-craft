import 'dart:convert';
import 'package:dio/dio.dart';

class MergePdf {
  final String outFileName;
  final List<MultipartFile> files;

  MergePdf({required this.outFileName, required this.files}) : assert(files.isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'merge-pdf-info': MultipartFile.fromString(
        jsonEncode({'out_file_name': outFileName}),
        contentType: DioMediaType.parse('application/json'),
      ),
      'files': files,
    };
  }
}
