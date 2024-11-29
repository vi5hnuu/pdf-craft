import 'package:dio/dio.dart';

class ReorderPdf{
  final String out_file_name;
  final List<int> order;// indexed
  final MultipartFile file;

  ReorderPdf({required this.out_file_name,required this.order,required this.file}):assert(order.isNotEmpty);
}