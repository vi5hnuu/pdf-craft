import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/WithHttpState.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import '../../models/HttpState.dart';

part 'files_event.dart';

part 'files_state.dart';

class FilesBloc extends Bloc<FilesEvent, FilesState> {
  StreamSubscription<File>? _searchSubscription;
  StreamController<List<File>>? _searchController;

  /// Upper bound on search results to keep the stream/UI responsive.
  static const _maxSearchResults = 300;

  FilesBloc() : super(FilesState.initial()) {
    on<LoadDirectoryFilesEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()
        ..put(HttpStates.LOAD_DIRECTORY_FILES, const HttpState.loading())));
      // await Future.delayed(Duration(seconds: 5));
      try {
        final files = await _loadDirectoryFiles(event.path);

        final fileStats = Map.fromEntries(await Future.wait(
          files.whereType<File>().map((file) async => MapEntry(file.path,await file.stat())),
        ));

        files.sort((fileA, fileB){
          if((fileA is Directory && fileB is Directory)) {
            return fileA.path.compareTo(fileB.path);
          } else if(fileA is Directory && fileB is File){
            return -1;
          }else if(fileB is Directory && fileA is File){
            return 1;
          }else{
            return fileStats[fileB.path]!.modified.compareTo(fileStats[fileA.path]!.modified);
          }

        });
        // await Future.delayed(Duration(seconds: 10));
        emit(state.copyWith(files: files, httpStates: state.httpStates.clone()
          ..put(HttpStates.LOAD_DIRECTORY_FILES,const HttpState.done())));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()
          ..put(HttpStates.LOAD_DIRECTORY_FILES,
              HttpState.error(error: e.toString()))));
      }
    });

    on<SearchFileEvent>((event, emit) async {
      // Cancel any in-flight search so a new query doesn't race the old one.
      await _searchSubscription?.cancel();
      await _searchController?.close();
      // A fresh stream per query so the UI resets (no stale results flashing)
      // and can show a "searching" state until the first emission.
      final controller = StreamController<List<File>>.broadcast();
      _searchController = controller;

      final List<File> files = [];
      _searchSubscription = searchFiles(event.path, event.nameLike).listen(
        (data) {
          files.add(data);
          if (!controller.isClosed) controller.add(List<File>.from(files));
          // Cap results to keep memory/UI bounded on huge trees.
          if (files.length >= _maxSearchResults) _searchSubscription?.cancel();
        },
        onError: controller.addError,
        // Emit the final list (possibly empty) so the UI can distinguish
        // "still searching" from "finished with no results".
        onDone: () {
          if (!controller.isClosed) controller.add(List<File>.from(files));
        },
      );
      emit(state.copyWith(searchStream: controller.stream));
    });

    on<ResetSearchEvent>((event, emit) async {
      if (_searchSubscription != null) await _searchSubscription!.cancel();
      if (_searchController != null) await _searchController!.close();
      _searchController=null;
      _searchSubscription=null;
      emit(state.copyWith(searchStream: null));
    });

    on<MoveFileToEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MOVE_FILE_TO, const HttpState.loading())));
      try{
        await _moveFile(file:event.file,toDirectoryPath:event.to);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MOVE_FILE_TO, const HttpState.done())));
      }catch(e){
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.MOVE_FILE_TO, HttpState.error(error: e.toString()))));
      }
    });

    on<DeleteFileEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.DELETE_FILE, const HttpState.loading())));
      try{
        await _deleteFile(file:event.file);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.DELETE_FILE, const HttpState.done())));
      }catch(e){
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.DELETE_FILE, HttpState.error(error: e.toString()))));
      }
    });
  }


  Future<List<FileSystemEntity>> _loadDirectoryFiles(String path) async {
    try {
      if (!await StoragePermissions.requestStoragePermissions()) {
        throw Exception("Permission denied");
      }
      if (Constants.isHiddenFileOrDir(path) ||
          Constants.excludedPaths.any((pth) => pth.endsWith(path))) {
        throw Exception("Permission denied");
      }

      Directory directory = Directory(path);
      if (directory.existsSync() == false) {
        throw Exception("Invalid directory path");
      }
      return directory.listSync(followLinks: false)..removeWhere((fileEntity)=>(fileEntity is Directory) && Constants.excludedPaths.contains(fileEntity.path));
    } catch (e) {
      throw Exception("Failed to load directory files");
    }
  }

  Stream<File> searchFiles(String directoryPath, String userInput) async* {
    if (!await StoragePermissions.requestStoragePermissions()) {
      return;
    }
    if (Constants.isHiddenFileOrDir(directoryPath) ||
        Constants.excludedPaths.any((path) => path.endsWith(directoryPath))) {
      return;
    }

    final directory = Directory(directoryPath);
    if (await directory.exists()) {
      await for (var entity in directory.list(recursive: false, followLinks: false)) {
        try {
          if (entity is File) {
            final fileName = entity.path
                .split('/')
                .last
                .toLowerCase();
            // Substring match (not just prefix) for a more forgiving search.
            if (!fileName.contains(userInput.toLowerCase())) continue;
            yield entity;
          } else if (entity is Directory) {
            yield* searchFiles(entity.path, userInput);
          }
        } on FileSystemException catch (e) {
          LoggerSingleton().logger.w("Failed to access ${entity.path}: $e");
          return;
        }
      }
    } else {
      LoggerSingleton().logger.w("Directory does not exist: $directoryPath");
    }
  }

  _moveFile({required File file, required String toDirectoryPath}) {
    Directory directoryTo=Directory(toDirectoryPath);

    if(!directoryTo.existsSync()){
      throw Exception("No such directory exists");
    }

    if (!file.existsSync()) {
      throw Exception("File does not exist in the source directory");
    }

    // Construct the new file path
    String newFilePath = "${directoryTo.path}/${file.path.split('/').last}";

    // Move the file
    try {
      file.renameSync(newFilePath);
    } catch (e) {
      throw Exception("Failed to move file: $e");
    }
  }

  Future<void> _deleteFile({required File file}) async {
    if (!file.existsSync()) {
      throw Exception("File does not exist");
    }

    try {
      await file.delete(); // Permanently deletes the file
    } catch (e) {
      throw Exception("Failed to delete the file: $e");
    }
  }

}
