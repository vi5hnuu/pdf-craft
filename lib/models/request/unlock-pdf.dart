import 'package:dio/dio.dart';

class UnlockPdf {
  final String out_file_name;
  final String password;
  final MultipartFile file;

  UnlockPdf({required this.out_file_name,required this.password,required this.file});
}
