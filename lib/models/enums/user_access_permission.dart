// ignore_for_file: constant_identifier_names
// These names are the wire contract: the API binds them to its own enum by constant name, so
// renaming them to lowerCamelCase would silently change what a live server receives. The lint
// is suppressed deliberately.

/// A permission the owner can grant to readers of a protected PDF.
///
/// Carries no PDF bit number. It used to, and `protect_pdf.dart` sent that number instead of the
/// name — which the API read as an enum *ordinal*, so bits 9 to 12 failed outright and 0 and 3
/// to 6 silently resolved to a different permission than the user had picked. The bit lives on
/// the server, which is the only place that needs it.
enum UserAccessPermission {
  PRINT,
  MODIFICATION,
  EXTRACT,
  MODIFY_ANNOTATIONS,
  FILL_IN_FORM,
  EXTRACT_FOR_ACCESSIBILITY,
  ASSEMBLE_DOCUMENT,
  FAITHFUL_PRINT,
  READ_ONLY,
}
