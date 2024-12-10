part of 'files_bloc.dart';

@immutable
abstract class FilesEvent {
  const FilesEvent();
}

class LoadDirectoryFilesEvent extends FilesEvent{
  final String path;
  const LoadDirectoryFilesEvent({required this.path});
}

class SearchFileEvent extends FilesEvent{
  final String path;
  final String nameLike;
  const SearchFileEvent({required this.path,required this.nameLike});
}

class ResetSearchEvent extends FilesEvent{
  const ResetSearchEvent();
}

class MoveFileToEvent extends FilesEvent{
  final File file;
  final String to;

  const MoveFileToEvent({required this.to,required this.file});
}


class DeleteFileEvent extends FilesEvent{
  final File file;
  const DeleteFileEvent({required this.file});
}