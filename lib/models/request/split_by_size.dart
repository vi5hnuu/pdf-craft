import 'dart:convert';
import 'package:dio/dio.dart';

/// Splits a PDF into parts no larger than [maxSizeMb] megabytes each.
class SplitBySize {
  final String? outFileName;
  final double maxSizeMb;
  final MultipartFile file;

  SplitBySize({this.outFileName, required this.maxSizeMb, required this.file});

  Map<String, dynamic> toJson() => {
        'split-by-size-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'max_size_mb': maxSizeMb,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
