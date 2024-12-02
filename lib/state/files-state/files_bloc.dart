import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
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

  FilesBloc() : super(FilesState.initial()) {
    on<LoadDirectoryFiles>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()
        ..put(HttpStates.LOAD_DIRECTORY_FILES, const HttpState.loading())));
      // await Future.delayed(Duration(seconds: 5));
      try {
        final files = await _loadDirectoryFiles(event.path);
        emit(state.copyWith(files: files, httpStates: state.httpStates.clone()
          ..put(HttpStates.LOAD_DIRECTORY_FILES,const HttpState.done())));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()
          ..put(HttpStates.LOAD_DIRECTORY_FILES,
              HttpState.error(error: e.toString()))));
      }
    });

    on<SearchFile>((event, emit) async {
      if (_searchSubscription != null) await _searchSubscription?.cancel();
      if (_searchController == null) _searchController=StreamController<List<File>>.broadcast();

      List<File> files = [];
      _searchSubscription = searchFiles(event.path, event.nameLike).listen(
            (data) {
          files.add(data);
          _searchController!.add(files);
        },
        onError: _searchController!.addError,
      );
      emit(state.copyWith(searchStream: _searchController!.stream));
    });

    on<ResetSearch>((event, emit) async {
      if (_searchSubscription != null) await _searchSubscription!.cancel();
      if (_searchController != null) await _searchController!.close();
      _searchController=null;
      _searchSubscription=null;
      emit(state.copyWith(searchStream: null));
    });
  }


  Future<List<FileSystemEntity>> _loadDirectoryFiles(String path) async {
    try {
      if (!await StoragePermissions.requestPermissions()) {
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
      return directory.listSync();
    } catch (e) {
      throw Exception("Failed to load directory files");
    }
  }

  Stream<File> searchFiles(String directoryPath, String userInput) async* {
    if (!await StoragePermissions.requestPermissions()) {
      return;
    }
    if (Constants.isHiddenFileOrDir(directoryPath) ||
        Constants.excludedPaths.any((path) => path.endsWith(directoryPath))) {
      return;
    }

    final directory = Directory(directoryPath);
    if (await directory.exists()) {
      await for (var entity in directory.list(
          recursive: false, followLinks: false)) {
        try {
          if (entity is File) {
            final fileName = entity.path
                .split('/')
                .last
                .toLowerCase();
            if (!fileName.startsWith(userInput.toLowerCase())) continue;
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

}
