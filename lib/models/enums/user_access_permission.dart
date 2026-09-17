// ignore_for_file: constant_identifier_names
// These values are the wire contract: the backend (and in several cases PDFBox itself)
// expects the SCREAMING_CASE spelling, either because the enum is serialised via `.name`
// or because its wire getter returns the same text. Renaming them to lowerCamelCase would
// silently change what a live server receives, so the lint is suppressed deliberately.

enum UserAccessPermission {
  PRINT(3),
  MODIFICATION(4),
  EXTRACT(5),
  MODIFY_ANNOTATIONS(6),
  FILL_IN_FORM(9),
  EXTRACT_FOR_ACCESSIBILITY(10),
  ASSEMBLE_DOCUMENT(11),
  FAITHFUL_PRINT(12),
  READ_ONLY(0);

  final int bit;

  const UserAccessPermission(this.bit);
}
