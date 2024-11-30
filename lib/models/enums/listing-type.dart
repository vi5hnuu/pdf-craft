enum ListingType {
  INTERNAL_STORAGE("INTERNAL_STORAGE"),
  DOWNLOADS("DOWNLOADS"),
  PROCESSED("PROCESSED");

  final String value;
  const ListingType(this.value);

  static ListingType fromJson(String value,{bool throwOnNull=false}){
    return ListingType.values.firstWhere((element) => element.value==value,orElse: () => throw Exception(""),);
  }
}
