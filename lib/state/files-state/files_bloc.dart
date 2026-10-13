import 'dart:async';
import 'package:pdf_craft/utils/utility.dart';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:pdf_craft/utils/output_filename.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/extensions/map_entensions.dart';
import 'package:pdf_craft/models/with_http_state.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/singletons/file_store.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/storage_permissions.dart';
import 'package:pdf_craft/utils/http_states.dart';
import '../../models/http_state.dart';

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
        ..put(HttpStates.loadDirectoryFiles, const HttpState.loading())));
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
          ..put(HttpStates.loadDirectoryFiles,const HttpState.done())));
      } catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()
          ..put(HttpStates.loadDirectoryFiles,
              // Raw exception text ("Exception: Failed to…") used to reach the user.
              HttpState.error(error: _logged(e, L10n.current.errLoadFolder)))));
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
      // Emissions are coalesced instead of one per match found.
      //
      // Every emission rebuilds the results list, and the screen re-shapes it — which in the
      // default date order stats every result. Emitting per match therefore cost N stats for
      // the Nth result: about 45,000 blocking syscalls on the UI thread over a full 300-result
      // search, which is what made searching feel like a freeze. The user cannot perceive
      // more than a handful of list updates a second anyway.
      Timer? coalesce;
      void publish() {
        coalesce?.cancel();
        coalesce = null;
        if (!controller.isClosed) controller.add(List<File>.from(files));
      }

      _searchSubscription = searchFiles(event.path, event.nameLike).listen(
        (data) {
          files.add(data);
          // First match publishes at once, so the list appears immediately rather than after
          // the interval; later ones ride the timer.
          if (files.length == 1) {
            publish();
          } else {
            coalesce ??= Timer(const Duration(milliseconds: 150), publish);
          }
          // Cap results to keep memory/UI bounded on huge trees.
          if (files.length >= _maxSearchResults) {
            publish();
            _searchSubscription?.cancel();
          }
        },
        onError: controller.addError,
        // Emit the final list (possibly empty) so the UI can distinguish
        // "still searching" from "finished with no results".
        onDone: publish,
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
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.moveFileTo, const HttpState.loading())));
      try{
        await _moveFile(file:event.file,toDirectoryPath:event.to);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.moveFileTo, const HttpState.done())));
      }catch(e){
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.moveFileTo, HttpState.error(error: _logged(e, L10n.current.errMoveFile)))));
      }
    });

    on<DeleteFileEvent>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.deleteFile, const HttpState.loading())));
      try{
        await _deleteFile(file:event.file);
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.deleteFile, const HttpState.done())));
      }catch(e){
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.deleteFile, HttpState.error(error: _logged(e, L10n.current.errDeleteFile)))));
      }
    });
  }


  /// Logs the technical error for debugging and returns the user-facing [message].
  String _logged(Object error, String message) {
    LoggerSingleton().logger.w('$message ($error)');
    return message;
  }

  Future<List<FileSystemEntity>> _loadDirectoryFiles(String path) async {
    try {
      if (!await StoragePermissions.requestStoragePermissions()) {
        throw Exception(L10n.current.filesPermissionDenied);
      }
      if (Constants.isHiddenFileOrDir(path) ||
          Constants.excludedPaths.any((pth) => pth.endsWith(path))) {
        throw Exception(L10n.current.filesPermissionDenied);
      }

      Directory directory = Directory(path);
      if (directory.existsSync() == false) {
        throw Exception(L10n.current.filesInvalidDirectory);
      }
      // list(), not listSync(): this enumerates an arbitrary device folder — the storage root,
      // DCIM, Download — and blocking the UI thread on it is what made opening a large folder
      // feel like a freeze.
      final entities = await directory.list(followLinks: false).toList();
      entities.removeWhere((fileEntity) =>
          (fileEntity is Directory) && Constants.excludedPaths.contains(fileEntity.path));
      return entities;
    } on Exception catch (e) {
      // Rethrown rather than flattened. The three throws above name a specific, actionable
      // cause — permission denied, or not a directory — and the blanket catch replaced every
      // one of them with "could not load files", so the user was never told it was a
      // permission problem they could actually fix.
      LoggerSingleton().logger.w('Listing ${Redact.path(path)} failed: $e');
      rethrow;
    } catch (e) {
      LoggerSingleton().logger.w('Listing ${Redact.path(path)} failed: $e');
      throw Exception(L10n.current.filesLoadFailed);
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
          // continue, not return: `return` ended the generator for this directory, so one
          // unreadable entry abandoned the rest of the folder — and, through the recursion,
          // everything below it.
          LoggerSingleton().logger.w("Failed to access ${Redact.path(entity.path)}: $e");
          continue;
        }
      }
    } else {
      LoggerSingleton().logger.w("Directory does not exist: ${Redact.path(directoryPath)}");
    }
  }

  _moveFile({required File file, required String toDirectoryPath}) {
    Directory directoryTo=Directory(toDirectoryPath);

    if(!directoryTo.existsSync()){
      throw Exception(L10n.current.filesNoSuchDirectory);
    }

    if (!file.existsSync()) {
      throw Exception(L10n.current.filesNotInSource);
    }

    // uniquePath, not a bare join: renameSync silently clobbers a file of the same name at the
    // destination, so moving report.pdf into a folder that already had one destroyed the
    // original. The helper is what _writeTo in PdfBloc already uses for exactly this.
    final newFilePath = uniquePath(directoryTo.path, Utility.fileName(file: file));

    try {
      file.renameSync(newFilePath);
    } catch (e) {
      throw Exception('${L10n.current.filesMoveFailed}: $e');
    }
  }

  Future<void> _deleteFile({required File file}) async {
    if (!file.existsSync()) {
      throw Exception(L10n.current.filesFileNotExist);
    }

    try {
      await file.delete(); // Permanently deletes the file
      FileStore().changed();
    } catch (e) {
      throw Exception('${L10n.current.filesDeleteFailed}: $e');
    }
  }

  /// Stops a device-wide search that is still running when the bloc goes away.
  ///
  /// Without this the recursive scan kept walking the whole filesystem after nothing was left
  /// to show it — wasted I/O and battery, and an emit into a closed bloc when it finished.
  @override
  Future<void> close() async {
    await _searchSubscription?.cancel();
    await _searchController?.close();
    return super.close();
  }
}
