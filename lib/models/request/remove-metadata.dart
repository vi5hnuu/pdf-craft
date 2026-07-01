import 'package:dio/dio.dart';

/// Only the file is sent — the backend strips all document info + XMP metadata.
class RemoveMetadata {
  final MultipartFile file;
  RemoveMetadata({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
