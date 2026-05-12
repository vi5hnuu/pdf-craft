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
