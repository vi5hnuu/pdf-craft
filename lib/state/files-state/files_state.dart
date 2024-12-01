part of 'files_bloc.dart';

@Immutable("cannot modify aarti state")
class FilesState extends Equatable with WithHttpState {
  final List<FileSystemEntity> files;

  FilesState._({
    this.files=const [],
    Map<String,HttpState>? httpStates,
  }){
    this.httpStates.addAll(httpStates ?? {});
  }

  FilesState.initial() : this._(httpStates: const {});

  FilesState copyWith({
    Map<String, HttpState>? httpStates,
  List<FileSystemEntity>? files,
  }) {
    return FilesState._(
      files: files ?? this.files,
      httpStates: httpStates ?? this.httpStates,
    );
  }

  @override
  List<Object?> get props => [httpStates,files];
}
