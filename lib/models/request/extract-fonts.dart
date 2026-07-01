import 'package:dio/dio.dart';

/// Only the file is sent — the backend returns a ZIP of embedded font programs.
class ExtractFonts {
  final MultipartFile file;
  ExtractFonts({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
