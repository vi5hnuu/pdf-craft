// ignore_for_file: constant_identifier_names
// These values are the wire contract: the backend (and in several cases PDFBox itself)
// expects the SCREAMING_CASE spelling, either because the enum is serialised via `.name`
// or because its wire getter returns the same text. Renaming them to lowerCamelCase would
// silently change what a live server receives, so the lint is suppressed deliberately.
enum FontName {
  TIMES_ROMAN("TIMES_ROMAN"),
  TIMES_BOLD("TIMES_BOLD"),
  TIMES_ITALIC("TIMES_ITALIC"),
  TIMES_BOLD_ITALIC("TIMES_BOLD_ITALIC"),
  HELVETICA("HELVETICA"),
  HELVETICA_BOLD("HELVETICA_BOLD"),
  HELVETICA_OBLIQUE("HELVETICA_OBLIQUE"),
  HELVETICA_BOLD_OBLIQUE("HELVETICA_BOLD_OBLIQUE"),
  COURIER("COURIER"),
  COURIER_BOLD("COURIER_BOLD"),
  COURIER_OBLIQUE("COURIER_OBLIQUE"),
  COURIER_BOLD_OBLIQUE("COURIER_BOLD_OBLIQUE"),
  SYMBOL("SYMBOL"),
  ZAPF_DINGBATS("ZAPF_DINGBATS");

  final String value;

  const FontName(this.value);
}