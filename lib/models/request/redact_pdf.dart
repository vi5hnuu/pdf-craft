import 'dart:convert';
import 'package:dio/dio.dart';

/// One rectangle to remove, as a fraction of its own page.
///
/// Fractions rather than points: converting to points here would mean converting against
/// whichever page happened to be open in the editor, so a bar drawn on one page landed
/// somewhere else on a page of a different size — leaving the content it was meant to
/// remove sitting in the file. The server resolves each region against its own page.
class RedactRegion {
  final int page;    // 0-indexed

  /// Top-left origin, 0.0-1.0, in the orientation the page is displayed in.
  final double xFrac;
  final double yFrac;
  final double widthFrac;
  final double heightFrac;

  const RedactRegion({
    required this.page,
    required this.xFrac,
    required this.yFrac,
    required this.widthFrac,
    required this.heightFrac,
  });

  Map<String, dynamic> toJson() => {
        'page': page,
        'x_frac': xFrac,
        'y_frac': yFrac,
        'width_frac': widthFrac,
        'height_frac': heightFrac,
      };
}

class RedactPdf {
  final String? outFileName;
  final List<RedactRegion> regions;
  final MultipartFile file;

  RedactPdf({this.outFileName, required this.regions, required this.file});

  Map<String, dynamic> toJson() => {
        'redact-pdf-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'regions': regions.map((r) => r.toJson()).toList(),
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
