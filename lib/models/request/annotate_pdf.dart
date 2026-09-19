import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pdf_craft/pages/annotate/annotation.dart';

/// Every mark in the document, in one request.
///
/// The annotate tool used to rasterise its marks and stamp one PNG per annotated page, uploading
/// the whole — and growing — PDF again for each. Ten annotated pages meant ten round trips over an
/// ever-larger file. The marks are geometry, so they go as geometry, once.
class AnnotatePdf {
  final MultipartFile file;
  final String outFileName;
  final List<Annotation> annotations;

  AnnotatePdf({
    required this.file,
    required this.outFileName,
    required this.annotations,
  });

  Map<String, dynamic> toJson() => {
        'annotate-pdf-info': MultipartFile.fromString(
          jsonEncode({
            'out_file_name': outFileName,
            // Images are not PDF annotations — they go through the stamp endpoint afterwards.
            'annotations': [
              for (final a in annotations)
                if (a.isPdfAnnotation) a.toWire(),
            ],
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
