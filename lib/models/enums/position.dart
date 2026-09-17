// ignore_for_file: constant_identifier_names
// These values are the wire contract: the backend (and in several cases PDFBox itself)
// expects the SCREAMING_CASE spelling, either because the enum is serialised via `.name`
// or because its wire getter returns the same text. Renaming them to lowerCamelCase would
// silently change what a live server receives, so the lint is suppressed deliberately.
enum WatermarkPosition {
  START,
  CENTER,
  END;

  String get displayName {
    switch (this) {
      case WatermarkPosition.START:
        return 'Start';
      case WatermarkPosition.CENTER:
        return 'Center';
      case WatermarkPosition.END:
        return 'End';
    }
  }
}
