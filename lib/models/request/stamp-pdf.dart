import 'dart:convert';
import 'package:dio/dio.dart';

/// Stamps artwork over a range of pages.
///
/// The stamp may be an image or a one-page PDF; the server decides which from its bytes.
/// The position fields are optional as a group — send none of them and the stamp is drawn at
/// its natural size, which is what this tool did before it could be positioned.
class StampPdf {
  final String? outFileName;
  final double opacity;
  final int fromPage;
  final int? toPage;

  /// Fractions of the page (0.0-1.0), origin top-left. All four or none.
  final double? xFrac;
  final double? yFrac;
  final double? widthFrac;
  final double? heightFrac;

  final MultipartFile file;  // the PDF
  final MultipartFile stamp; // the stamp artwork: an image or a one-page PDF

  StampPdf({
    this.outFileName,
    this.opacity = 0.5,
    this.fromPage = 0,
    this.toPage,
    this.xFrac,
    this.yFrac,
    this.widthFrac,
    this.heightFrac,
    required this.file,
    required this.stamp,
  });

  Map<String, dynamic> toJson() => {
        'stamp-pdf-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'opacity': opacity,
            'from_page': fromPage,
            if (toPage != null) 'to_page': toPage,
            if (_hasPlacement) 'x_frac': xFrac,
            if (_hasPlacement) 'y_frac': yFrac,
            if (_hasPlacement) 'width_frac': widthFrac,
            if (_hasPlacement) 'height_frac': heightFrac,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
        'stamp': stamp,
      };

  /// A partial box would be silently ignored by the server, so it is all four or nothing.
  bool get _hasPlacement =>
      xFrac != null && yFrac != null && widthFrac != null && heightFrac != null;
}
