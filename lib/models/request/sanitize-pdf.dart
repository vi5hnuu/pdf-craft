import 'package:dio/dio.dart';

/// Only the file is sent — the backend strips JavaScript, embedded files,
/// actions and metadata.
class SanitizePdf {
  final MultipartFile file;
  SanitizePdf({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
