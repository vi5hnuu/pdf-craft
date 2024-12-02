import 'package:dio/dio.dart';

class ImageToPdf {
  final String out_file_name; //zip name/single image name is single=true
  final List<MultipartFile> files;

  ImageToPdf({required this.out_file_name,required this.files});

  Map<String,dynamic> toJson() {
    return {
      "out_file_name":out_file_name,
      "files":files,
    };
  }
}

