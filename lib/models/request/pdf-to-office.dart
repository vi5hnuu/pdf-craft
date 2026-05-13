import 'dart:convert';
import 'package:dio/dio.dart';

/// Which Office format to convert to
enum PdfOfficeFormat { word, excel, pptx }

class PdfToOffice {
  final String? outFileName;
  final PdfOfficeFormat format;
  final MultipartFile file;

  PdfToOffice({this.outFileName, required this.format, required this.file});

  Map<String, dynamic> toJson() {
    final info = <String, dynamic>{};
    if (outFileName != null && outFileName!.isNotEmpty) {
      info['out_file_name'] = outFileName;
    }
    return {
      'pdf-to-office-info': MultipartFile.fromString(
        jsonEncode(info),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
