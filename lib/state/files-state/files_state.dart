part of 'files_bloc.dart';

@Immutable("cannot modify aarti state")
class FilesState extends Equatable with WithHttpState {
  final List<FileSystemEntity> files;
  final List<FileSystemEntity> selectedFiles;
  final Stream<List<File>>? searchStream;

  FilesState._({
    this.files=const [],
    this.searchStream,
    this.selectedFiles=const [],
    Map<String,HttpState>? httpStates,
  }){
    this.httpStates.addAll(httpStates ?? {});
  }

  FilesState.initial() : this._(httpStates: const {});

  FilesState copyWith({
    Map<String, HttpState>? httpStates,
  List<FileSystemEntity>? files,
    Stream<List<File>>? searchStream,
  List<FileSystemEntity>? selectedFiles,
  }) {
    return FilesState._(
      files: files ?? this.files,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      searchStream: searchStream ?? this.searchStream,
      httpStates: httpStates ?? this.httpStates,
    );
  }

  FileSystemEntity? getSelectedFile(FileSystemEntity file) {
    try{
      return selectedFiles.firstWhere((f)=>f.path==file.path);
    }catch(e){
      return null;
    }
  }

  @override
  List<Object?> get props => [httpStates,files,selectedFiles,searchStream];

}
