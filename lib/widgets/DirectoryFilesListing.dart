import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:rxdart/rxdart.dart';

class SystemFiles {
  final List<FileSystemEntity> files;
  final bool? isLoading;
  final String? error;

  const SystemFiles({required this.files, this.isLoading, this.error});

  SystemFiles copyWith(
      {List<FileSystemEntity>? newFiles, bool? loading, String? err}) {
    return SystemFiles(
        files: newFiles ?? files,
        isLoading: loading ?? isLoading,
        error: err ?? error);
  }
}

class DirectoryFilesListing extends StatefulWidget {
  final String directoryPath;

  const DirectoryFilesListing({super.key, required this.directoryPath});

  @override
  State<DirectoryFilesListing> createState() => _DirectoryFilesListingState();
}

class _DirectoryFilesListingState extends State<DirectoryFilesListing> {
  late final FilesBloc bloc;
  List<String> pathToDirectory = [];

  @override
  void initState() {
    bloc=BlocProvider.of<FilesBloc>(context);
    pathToDirectory = [widget.directoryPath];
    _loadDirectoryFiles(pathToDirectory.last);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        body: SafeArea(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (pathToDirectory.length <= 1) {
            GoRouter.of(context).pop();
          } else {
            setState(() {
              pathToDirectory.removeLast();
              _loadDirectoryFiles(pathToDirectory.last);
            });
          }
        },
        child:  BlocConsumer<FilesBloc,FilesState>(listener: (context, state) {
          final error=state.getError(forr: HttpStates.LOAD_DIRECTORY_FILES);
          if(error==null) return;
          NotificationService.showSnackbar(text: error,color: Colors.red);
        },
          buildWhen: (previous, current) => previous!=current,
          listenWhen: (previous, current) => previous!=current,
          builder: (context, state) {
          return Stack(children: [
            if(!state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES))(state.files.isEmpty
                ? const Center(child: Text('No files found'))
                : ListView.builder(
                itemCount: state.files.length,
                itemBuilder: (context, index) {
                  final file = state.files[index];
                  return ListTile(
                    leading: file is Directory
                        ? const Icon(FontAwesomeIcons.solidFolder,
                        color: Colors.yellowAccent)
                        : const Icon(FontAwesomeIcons.file,
                        color: Colors.green),
                    title: Text(file.path.split('/').last),
                    subtitle: Text(
                        '${file is Directory ? 'Directory' : '${File(file.path).lengthSync()} bytes'}'),
                    onTap: file is! Directory
                        ? null
                        : () {
                      pathToDirectory = [
                        ...pathToDirectory,
                        file.path
                      ];
                      _loadDirectoryFiles(pathToDirectory.last);
                    },
                  );
                })),
            if (state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES))
              Expanded(
                  child: Container(
                    decoration:BoxDecoration(color: Colors.black.withOpacity(0.8)),
                    child: const Align(alignment: Alignment.center, child: SpinKitRipple(size: 72, color: Colors.green)),
                  )),
          ]);
        },),
      ),
    ));
  }

  _loadDirectoryFiles(String path){
    if(bloc.state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES)) return;
    bloc.add(LoadDirectoryFiles(path: pathToDirectory.last));
  }

  @override
  void dispose() {
    bloc.add(const ResetFilesState());
    super.dispose();
  }
}
