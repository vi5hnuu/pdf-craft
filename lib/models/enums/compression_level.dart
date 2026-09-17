// ignore_for_file: constant_identifier_names
// These values are the wire contract: the backend (and in several cases PDFBox itself)
// expects the SCREAMING_CASE spelling, either because the enum is serialised via `.name`
// or because its wire getter returns the same text. Renaming them to lowerCamelCase would
// silently change what a live server receives, so the lint is suppressed deliberately.
enum CompressionLevel {
  EXTREME,
  RECOMMENDED,
  LOW;

  String get displayName {
    switch (this) {
      case CompressionLevel.EXTREME:
        return 'Extreme (Smallest size)';
      case CompressionLevel.RECOMMENDED:
        return 'Recommended (Balanced)';
      case CompressionLevel.LOW:
        return 'Low (Best quality)';
    }
  }
}
