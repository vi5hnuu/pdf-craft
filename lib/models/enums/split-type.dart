enum SplitType {
  SPLIT_BY_RANGE("SPLIT_BY_RANGE"),
  FIXED_RANGE("FIXED_RANGE"),
  DELETE_PAGES("DELETE_PAGES"),
  EXTRACT_ALL_PAGES("EXTRACT_ALL_PAGES");

  final String type;
  const SplitType(this.type);
}
