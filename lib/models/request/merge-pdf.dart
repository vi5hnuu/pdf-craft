import 'dart:io';

class MergePdf{
  final String out_file_name;
  final List<File> files;

  MergePdf({required this.out_file_name,required this.files}):assert(files.isNotEmpty);
}