import 'package:dio/dio.dart';

class GetMetadata {
  final MultipartFile file;

  GetMetadata({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
