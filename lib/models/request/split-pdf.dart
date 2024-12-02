import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/split-type.dart';

class SplitPdf{
  final String out_file_name;
  final SplitType type;
  final int? fixed;
  final List<RangeModel>? ranges;
  final MultipartFile file;

  SplitPdf({required this.out_file_name,required this.type,required this.fixed,required this.ranges,required this.file});
}


class RangeModel {
  final int from;
  final int to;

  RangeModel({required this.from,required this.to});
}