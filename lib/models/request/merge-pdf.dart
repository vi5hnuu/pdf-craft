import 'package:dio/dio.dart';

class MergePdf{
  final String out_file_name;
  final List<MultipartFile> files;

  MergePdf({required this.out_file_name,required this.files}):assert(files.isNotEmpty);
}