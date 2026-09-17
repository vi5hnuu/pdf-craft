import 'dart:convert';
import 'package:dio/dio.dart';

/// Multipart request for `create-form`.
///
/// The field specs are produced by `AcroFormSpecMapper` in the `form_engine`
/// package, which owns the wire contract (coordinates in PDF points with a
/// top-left origin, 0-indexed pages) and has a golden test pinning the exact
/// JSON the backend parses. Passing the maps straight through keeps one
/// representation instead of copying it into a second DTO on the way out.
class CreateForm {
  final String? outFileName;
  final List<Map<String, Object?>> fields;
  final MultipartFile file;

  CreateForm({this.outFileName, required this.fields, required this.file});

  Map<String, dynamic> toJson() => {
        'create-form-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'fields': fields,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
