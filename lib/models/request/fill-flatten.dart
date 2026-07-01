import 'dart:convert';
import 'package:dio/dio.dart';

/// Fills the PDF's existing form fields with [values] (by field name), then flattens.
class FillFlatten {
  final String? outFileName;
  final Map<String, String> values;
  final MultipartFile file;

  FillFlatten({this.outFileName, required this.values, required this.file});

  Map<String, dynamic> toJson() => {
        'fill-flatten-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'values': values,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
