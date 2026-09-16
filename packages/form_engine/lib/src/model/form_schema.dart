import 'form_field.dart';
import 'geometry.dart';
import 'recipient.dart';

/// A whole form: every field placed on a document, plus the page sizes needed to
/// turn fractional rects back into PDF points.
class FormSchema {
  /// Bumped only when a change cannot be read by the previous version.
  /// `SchemaCodec` migrates older documents forward on load.
  ///
  /// v2: rules reference field **ids** rather than names, so renaming a field no longer
  ///     silently rewires what its dependants compute.
  static const int currentVersion = 2;

  final int version;

  final List<FormFieldModel> fields;

  /// Page number (1-based) to its size in PDF points. Needed at export time;
  /// stored so a schema saved as a template can be re-checked against another
  /// document later.
  final Map<int, PageSizePoints> pageSizes;

  /// Stable identity for the document itself, so a draft, a template and an exported file
  /// can be correlated later without relying on the file name.
  final String? documentId;

  /// Author-facing title, independent of the PDF's file name.
  final String? title;

  /// When the layout was last edited, in UTC.
  final DateTime? updatedAt;

  /// Roles a field can be assigned to. Empty today (single-device filling); present so
  /// send-to-fill is an addition rather than a migration.
  final List<Recipient> recipients;

  FormSchema({
    this.version = currentVersion,
    List<FormFieldModel>? fields,
    Map<int, PageSizePoints>? pageSizes,
    this.documentId,
    this.title,
    this.updatedAt,
    List<Recipient>? recipients,
  })  : fields = fields ?? <FormFieldModel>[],
        pageSizes = pageSizes ?? <int, PageSizePoints>{},
        recipients = recipients ?? const <Recipient>[];

  /// Field lookup by id, for resolving rule references.
  Map<String, FormFieldModel> get byId => {for (final f in fields) f.id: f};

  /// Fields on [page], in the order they were added (which is also tab order).
  List<FormFieldModel> fieldsOnPage(int page) =>
      fields.where((f) => f.page == page).toList(growable: false);

  /// Radio groups present in the form, mapped to their member fields.
  ///
  /// Grouping matters because a PDF radio group is one field with several
  /// widgets, not several fields.
  Map<String, List<FormFieldModel>> radioGroups(bool Function(String typeId) isRadio) {
    final out = <String, List<FormFieldModel>>{};
    for (final f in fields) {
      if (!isRadio(f.typeId)) continue;
      out.putIfAbsent(f.group, () => <FormFieldModel>[]).add(f);
    }
    return out;
  }
}
