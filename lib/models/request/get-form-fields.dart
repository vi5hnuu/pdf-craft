import 'package:dio/dio.dart';

/// Only the file is sent — the backend returns the PDF's existing form fields as JSON.
class GetFormFields {
  final MultipartFile file;
  GetFormFields({required this.file});

  Map<String, dynamic> toJson() => {'file': file};
}
