part of 'files_bloc.dart';

@immutable
abstract class FilesEvent {
  const FilesEvent();
}

class LoadDirectoryFiles extends FilesEvent{
  final String path;
  const LoadDirectoryFiles({required this.path});
}

class ResetFilesState extends FilesEvent{
  const ResetFilesState();
}