// ignore_for_file: constant_identifier_names
// These values are the wire contract: the backend (and in several cases PDFBox itself)
// expects the SCREAMING_CASE spelling, either because the enum is serialised via `.name`
// or because its wire getter returns the same text. Renaming them to lowerCamelCase would
// silently change what a live server receives, so the lint is suppressed deliberately.
enum PageNoType {
  ONLY_X("X"),
  PAGE_X_OF_Y("page_X_of_Y"),
  PAGE_X("page_X");

  final String type;

  const PageNoType(this.type);
}
