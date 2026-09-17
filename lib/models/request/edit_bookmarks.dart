import 'dart:convert';
import 'package:dio/dio.dart';

class EditBookmarks {
  final String? outFileName;
  // JSON-stringified List<{title, pageIndex, children[]}> bookmark tree
  final String bookmarksJson;
  final MultipartFile file;

  EditBookmarks({
    this.outFileName,
    required this.bookmarksJson,
    required this.file,
  });

  Map<String, dynamic> toJson() => {
        'edit-bookmarks-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'bookmarks': bookmarksJson,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
