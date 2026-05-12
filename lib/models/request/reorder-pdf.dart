import 'dart:convert';
import 'package:dio/dio.dart';

class ReorderPdf {
  final String out_file_name;
  final List<int> order; // 0-indexed page order
  final MultipartFile file;

  ReorderPdf({required this.out_file_name, required this.order, required this.file})
      : assert(order.isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'reorder-pdf-info': MultipartFile.fromString(
        jsonEncode({
          'out_file_name': out_file_name,
          'order': order, // backend expects int[] JSON array, not comma-string
        }),
        contentType: DioMediaType.parse('application/json'),
      ),
      'file': file,
    };
  }
}
