import 'dart:convert';
import 'package:dio/dio.dart';

class MergePdf {
  final String outFileName;
  final List<MultipartFile> files;

  /// Two files minimum, matching the server's @ValidateUpload(minFiles = 2). Asserting only
  /// non-empty let a one-file merge upload and come back as an opaque 400.
  MergePdf({required this.outFileName, required this.files})
      : assert(files.length >= 2, 'merge needs at least two files');

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
