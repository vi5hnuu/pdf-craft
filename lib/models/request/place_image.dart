import 'dart:convert';
import 'package:dio/dio.dart';

/// Places an image on one or more pages of a PDF.
///
/// The server fits the image inside the requested box keeping its proportions unless
/// [stretch] is set, which is what the editor's "Free" resize mode means.
class PlaceImage {
  final String? outFileName;
  final int page;       // 0-indexed
  final double xFrac;   // left edge as fraction of page width (0.0–1.0)
  final double yFrac;   // top edge as fraction of page height (0.0–1.0)
  final double widthFrac;
  final double heightFrac;
  /// Extra 0-indexed pages to place the same image on. Empty means [page] alone.
  final List<int> pages;
  /// Fill the box exactly, distorting the image. Only when the user asked for it.
  final bool stretch;
  final MultipartFile file;  // the PDF
  final MultipartFile image; // the image to place

  PlaceImage({
    this.outFileName,
    required this.page,
    this.pages = const [],
    this.stretch = false,
    required this.xFrac,
    required this.yFrac,
    required this.widthFrac,
    required this.heightFrac,
    required this.file,
    required this.image,
  });

  Map<String, dynamic> toJson() => {
        'place-image-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'page': page,
            'x_frac': xFrac,
            'y_frac': yFrac,
            'width_frac': widthFrac,
            'height_frac': heightFrac,
            if (pages.isNotEmpty) 'pages': pages,
            'fit': stretch ? 'STRETCH' : 'CONTAIN',
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
        'image': image,
      };
}
