import 'package:dio/dio.dart';

// No info part — only the file is sent
class GetBookmarks {
  final MultipartFile file;
  GetBookmarks({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
