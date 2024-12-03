enum Quality {
  LOW(72),
  MEDIUM(150),
  HIGH(300);

  final int dpi;

  const Quality(this.dpi);

  static fromDpi(int dpi){
    return Quality.values.firstWhere((quality)=>quality.dpi==dpi);
  }
}
