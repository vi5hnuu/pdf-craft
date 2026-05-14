import 'dart:convert';
import 'package:dio/dio.dart';

class RemoveBlankPages {
  final String? outFileName;
  final double threshold;
  final MultipartFile file;

  RemoveBlankPages({this.outFileName, this.threshold = 0.98, required this.file});

  Map<String, dynamic> toJson() => {
        'remove-blank-pages-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'threshold': threshold,
          }),
          contentType: 'application/json',
        ),
        'file': file,
      };
}
