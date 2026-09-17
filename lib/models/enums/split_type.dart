// ignore_for_file: constant_identifier_names
// These values are the wire contract: the backend (and in several cases PDFBox itself)
// expects the SCREAMING_CASE spelling, either because the enum is serialised via `.name`
// or because its wire getter returns the same text. Renaming them to lowerCamelCase would
// silently change what a live server receives, so the lint is suppressed deliberately.
enum SplitType {
  SPLIT_BY_RANGE("SPLIT_BY_RANGE"),
  FIXED_RANGE("FIXED_RANGE"),
  DELETE_PAGES("DELETE_PAGES"),
  EXTRACT_ALL_PAGES("EXTRACT_ALL_PAGES"),
  SPLIT_BY_BOOKMARK("SPLIT_BY_BOOKMARK");

  final String type;
  const SplitType(this.type);

  static SplitType fromJson(String splitType){
    return SplitType.values.firstWhere((type)=>type.type.toLowerCase()==splitType.toLowerCase());
  }
}
