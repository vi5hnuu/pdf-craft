import 'package:dio/dio.dart';

/// Only the file is sent — the backend returns a JSON analysis report.
class AnalyzePdf {
  final MultipartFile file;
  AnalyzePdf({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
