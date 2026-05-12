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
