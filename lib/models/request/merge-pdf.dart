import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';

class MergePdf{
  final String out_file_name;
  final List<MultipartFile> files;

  MergePdf({required this.out_file_name,required this.files}):assert(files.isNotEmpty);

  Map<String,dynamic> toJson() {
    return {
      'out_file_name':out_file_name,
      'files':files
    };
  }
}