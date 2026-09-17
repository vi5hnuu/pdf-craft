import 'package:dio/dio.dart';

/// Only the file is sent — the backend returns a ZIP of the embedded images.
class ExtractImages {
  final MultipartFile file;
  ExtractImages({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
