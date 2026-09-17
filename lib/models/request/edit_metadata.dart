import 'dart:convert';
import 'package:dio/dio.dart';

class EditMetadata {
  final String? outFileName;
  final String? title;
  final String? author;
  final String? subject;
  final String? keywords;
  final String? creator;
  final String? producer;
  final MultipartFile file;

  EditMetadata({
    this.outFileName,
    this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creator,
    this.producer,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'edit-metadata-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            if (title != null) 'title': title,
            if (author != null) 'author': author,
            if (subject != null) 'subject': subject,
            if (keywords != null) 'keywords': keywords,
            if (creator != null) 'creator': creator,
            if (producer != null) 'producer': producer,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
