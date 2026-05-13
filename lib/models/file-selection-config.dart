class FileSelectionConfig{
  final String path;
  final bool? multiSelect;
  final List<String> limitToExtensions;//empty means all select allow
  final String? redirectPath;
  final int? minSelection;
  final List<String>? excludeShowingDirsPath;
  // Additional data merged into the route extra alongside 'files'
  final Map<String, dynamic>? extra;

  FileSelectionConfig({this.excludeShowingDirsPath,required this.path,this.multiSelect,this.limitToExtensions=const [],this.redirectPath,this.minSelection,this.extra});
}