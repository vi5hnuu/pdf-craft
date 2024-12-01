import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/WithHttpState.dart';
import 'package:pdf_craft/services/apis/PdfService.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import '../../models/HttpState.dart';

part 'files_event.dart';

part 'files_state.dart';

class FilesBloc extends Bloc<FilesEvent, FilesState> {
  FilesBloc() : super(FilesState.initial()) {

    on<LoadDirectoryFiles>((event, emit) async {
      emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.LOAD_DIRECTORY_FILES, const HttpState.loading())));
      // await Future.delayed(Duration(seconds: 5));
      try {
        final files = await _loadDirectoryFiles(event.path);
        emit(state.copyWith(files: files,httpStates: state.httpStates.clone()..remove(HttpStates.LOAD_DIRECTORY_FILES)));
      }catch (e) {
        emit(state.copyWith(httpStates: state.httpStates.clone()..put(HttpStates.LOAD_DIRECTORY_FILES, HttpState.error(error: e.toString()))));
      }
    });

    on<ResetFilesState>((event, emit) async {
      emit(FilesState.initial());
    });
  }

  Future<List<FileSystemEntity>> _loadDirectoryFiles(String path) async {
    try {
      if (!await StoragePermissions.requestPermissions()) {
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
}
