import 'package:dio/dio.dart';

class UnProtectPdf {
  final String out_file_name;
  final String password;
  final MultipartFile file;

  UnProtectPdf({required this.out_file_name,required this.password,required this.file});
}
