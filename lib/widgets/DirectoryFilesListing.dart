import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
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
  BehaviorSubject<SystemFiles> systemFilesController =
      BehaviorSubject.seeded(const SystemFiles(files: [], isLoading: true));
  List<String> pathToDirectory = [];

  @override
  void initState() {
    pathToDirectory = [widget.directoryPath];
    _checkAndLoadFiles(pathToDirectory.last);
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
              _checkAndLoadFiles(pathToDirectory.last);
            });
          }
        },
        child: StreamBuilder<SystemFiles>(
          stream: systemFilesController.stream,
          builder: (context, snapshot) {
            final systemFiles = snapshot.data!;
            return Stack(children: [
              systemFiles.files.isEmpty
                  ? const Center(child: Text('No files found'))
                  : ListView.builder(
                      itemCount: systemFiles.files.length,
                      itemBuilder: (context, index) {
                        final file = systemFiles.files[index];
                        return ListTile(
                          leading: file is Directory
                              ? Icon(FontAwesomeIcons.solidFolder,
                                  color: Colors.yellowAccent)
                              : Icon(FontAwesomeIcons.file,
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
                                  _checkAndLoadFiles(file.path);
                                },
                        );
                      }),
              if (systemFilesController.value.isLoading == true)
                Expanded(
                    child: Container(
                  decoration:BoxDecoration(color: Colors.black.withOpacity(0.8)),
                  child: const Align(alignment: Alignment.center, child: SpinKitRipple(size: 72, color: Colors.green)),
                )),
            ]);
          },
        ),
      ),
    ));
  }

  Future<void> _checkAndLoadFiles(String path) async {
    if (await StoragePermissions.requestPermissions()) {
      await _loadFiles(path);
    } else {
      NotificationService.showSnackbar(
          text: "Permission denied", color: Colors.red, showCloseIcon: true);
    }
  }

  Future<void> _loadFiles(String path) async {
    try {
      systemFilesController.sink
          .add(systemFilesController.value.copyWith(loading: true));
      // await Future.delayed(Duration(minutes: 5));
      Directory directory = Directory(path);
      if (directory.existsSync() == false) {
        systemFilesController.sink
            .add(systemFilesController.value.copyWith(loading: false));
        NotificationService.showSnackbar(
            text: "Directory does not exists",
            color: Colors.red,
            showCloseIcon: true);
        return;
      }
      List<FileSystemEntity> files = directory.listSync();
      systemFilesController.sink.add(SystemFiles(files: files));
    } catch (e) {
      setState(() => pathToDirectory.removeLast());
      NotificationService.showSnackbar(
          text: "Failed to show directory files",
          color: Colors.red,
          showCloseIcon: true);
    } finally {
      systemFilesController.sink
          .add(systemFilesController.value.copyWith(loading: false));
    }
  }
}
