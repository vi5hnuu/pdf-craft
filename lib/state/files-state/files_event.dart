part of 'files_bloc.dart';

@immutable
abstract class FilesEvent {
  const FilesEvent();
}

class LoadDirectoryFiles extends FilesEvent{
  final String path;
  const LoadDirectoryFiles({required this.path});
}

class SearchFile extends FilesEvent{
  final String path;
  final String nameLike;
  const SearchFile({required this.path,required this.nameLike});
}

class ResetSearch extends FilesEvent{
  const ResetSearch();
}