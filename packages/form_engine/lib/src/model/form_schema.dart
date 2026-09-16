import 'form_field.dart';
import 'geometry.dart';

/// A whole form: every field placed on a document, plus the page sizes needed to
/// turn fractional rects back into PDF points.
class FormSchema {
  /// Bumped only when a change cannot be read by the previous version.
  /// `SchemaCodec` migrates older documents forward on load.
  static const int currentVersion = 1;

  final int version;

  final List<FormFieldModel> fields;

  /// Page number (1-based) to its size in PDF points. Needed at export time;
  /// stored so a schema saved as a template can be re-checked against another
  /// document later.
  final Map<int, PageSizePoints> pageSizes;

  FormSchema({
    this.version = currentVersion,
    List<FormFieldModel>? fields,
    Map<int, PageSizePoints>? pageSizes,
  })  : fields = fields ?? <FormFieldModel>[],
        pageSizes = pageSizes ?? <int, PageSizePoints>{};

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
