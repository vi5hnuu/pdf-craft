// ignore_for_file: constant_identifier_names
// These values are the wire contract: the backend (and in several cases PDFBox itself)
// expects the SCREAMING_CASE spelling, either because the enum is serialised via `.name`
// or because its wire getter returns the same text. Renaming them to lowerCamelCase would
// silently change what a live server receives, so the lint is suppressed deliberately.
import 'package:pdf_craft/utils/constants.dart';

enum ListingType {
  INTERNAL_STORAGE("INTERNAL_STORAGE",Constants.rootStoragePath),
  DOWNLOADS("DOWNLOADS",Constants.downloadsStoragePath),
  DOCUMENTS("DOCUMENTS",Constants.documentsStoragePath);

  final String value;
  final String path;
  const ListingType(this.value,this.path);

  static ListingType fromJson(String value,{bool throwOnNull=false}){
    return ListingType.values.firstWhere((element) => element.value==value,orElse: () => throw Exception(""),);
  }
}
