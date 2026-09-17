import 'dart:convert';
import 'package:dio/dio.dart';

class NUp {
  final String? outFileName;
  final int nUp;
  final MultipartFile file;

  NUp({this.outFileName, this.nUp = 2, required this.file});

  Map<String, dynamic> toJson() => {
        'n-up-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'n_up': nUp,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
