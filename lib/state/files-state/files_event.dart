part of 'files_bloc.dart';

@immutable
abstract class FilesEvent {
  const FilesEvent();
}

class LoadDirectoryFiles extends FilesEvent{
  final String path;
  const LoadDirectoryFiles({required this.path});
}

class ToggleFileSelection extends FilesEvent{
  final FileSystemEntity file;
  const ToggleFileSelection({required this.file});
}

class SearchFile extends FilesEvent{
  final String path;
  final String nameLike;
  const SearchFile({required this.path,required this.nameLike});
}

class ResetFilesState extends FilesEvent{
  const ResetFilesState();
}