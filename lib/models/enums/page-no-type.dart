enum PageNoType {
  ONLY_X("X"),
  PAGE_X_OF_Y("page_X_of_Y"),
  PAGE_X("page_X");

  final String type;

  const PageNoType(this.type);
}
