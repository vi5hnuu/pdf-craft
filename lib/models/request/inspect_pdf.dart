import 'package:dio/dio.dart';

/// The request every read-only inspector sends: the file, plus optional query parameters.
///
/// One model for six endpoints, because they differ only in the URL and in a couple of query
/// flags — a class per tool would be six identical files. The response shape differs per tool and
/// is read straight from JSON by the view that asked for it.
class InspectPdf {
  final MultipartFile file;

  /// Query string parameters (`offset`/`limit` for the object explorer, `include-text` for the
  /// JSON export). Sent on the URL, not in the body, because they are not part of the upload.
  final Map<String, dynamic> query;

  InspectPdf({required this.file, this.query = const {}});

  Map<String, dynamic> toJson() => {'file': file};
}
