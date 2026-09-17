import 'dart:convert';
import 'package:dio/dio.dart';

class ReorderPdf {
  final String outFileName;
  final List<int> order; // 0-indexed page order
  final MultipartFile file;

  ReorderPdf({required this.outFileName, required this.order, required this.file})
      : assert(order.isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'reorder-pdf-info': MultipartFile.fromString(
        jsonEncode({
          'out_file_name': outFileName,
          'order': order, // backend expects int[] JSON array, not comma-string
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
