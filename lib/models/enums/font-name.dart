// Maps to Java's Standard14Fonts.FontName enum used by PDFBox
enum PdfFontName {
  HELVETICA,
  HELVETICA_BOLD,
  HELVETICA_OBLIQUE,
  HELVETICA_BOLD_OBLIQUE,
  COURIER,
  COURIER_BOLD,
  COURIER_OBLIQUE,
  COURIER_BOLD_OBLIQUE,
  TIMES_ROMAN,
  TIMES_BOLD,
  TIMES_ITALIC,
  TIMES_BOLD_ITALIC;

  String get displayName {
    switch (this) {
      case PdfFontName.HELVETICA:            return 'Helvetica';
      case PdfFontName.HELVETICA_BOLD:       return 'Helvetica Bold';
      case PdfFontName.HELVETICA_OBLIQUE:    return 'Helvetica Italic';
      case PdfFontName.HELVETICA_BOLD_OBLIQUE: return 'Helvetica Bold Italic';
      case PdfFontName.COURIER:              return 'Courier';
      case PdfFontName.COURIER_BOLD:         return 'Courier Bold';
      case PdfFontName.COURIER_OBLIQUE:      return 'Courier Italic';
      case PdfFontName.COURIER_BOLD_OBLIQUE: return 'Courier Bold Italic';
      case PdfFontName.TIMES_ROMAN:          return 'Times Roman';
      case PdfFontName.TIMES_BOLD:           return 'Times Bold';
      case PdfFontName.TIMES_ITALIC:         return 'Times Italic';
      case PdfFontName.TIMES_BOLD_ITALIC:    return 'Times Bold Italic';
    }
  }
}
