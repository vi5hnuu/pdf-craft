import 'package:dio/dio.dart';

/// Only the file is sent — the backend returns a ZIP of the embedded attachments.
class ExtractEmbeddedFiles {
  final MultipartFile file;
  ExtractEmbeddedFiles({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
