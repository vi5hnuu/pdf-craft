import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/enums/listing-type.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';

class FilesListing extends StatefulWidget {
  final ListingType type;

  const FilesListing({super.key, required this.type});

  @override
  State<FilesListing> createState() => _FilesListingState();
}

class _FilesListingState extends State<FilesListing> {
  List<FileSystemEntity> files = const [];
  List<String> pathToDirectory = [];

  @override
  void initState() {
    var initialPath = widget.type == ListingType.INTERNAL_STORAGE
        ? Constants.rootStoragePath
        : Constants.downloadsStoragePath;
    pathToDirectory = [initialPath];
    _checkAndLoadFiles(initialPath);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop,result) {
          if(didPop) return;
          if(pathToDirectory.length<=1){
            GoRouter.of(context).pop();
          }else{
            setState(() {
              pathToDirectory.removeLast();
              _checkAndLoadFiles(pathToDirectory.last);
            });
          }
        },
        child: files.isEmpty
            ? const Center(child: Text('No files found'))
            : ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return ListTile(
                    leading: file is Directory
                        ? Icon(FontAwesomeIcons.solidFolder,
                            color: Colors.yellowAccent)
                        : Icon(FontAwesomeIcons.file, color: Colors.green),
                    title: Text(file.path.split('/').last),
                    subtitle: Text(
                        '${file is Directory ? 'Directory' : '${File(file.path).lengthSync()} bytes'}'),
                    onTap: file is! Directory
                        ? null
                        : () {
                            pathToDirectory = [...pathToDirectory, file.path];
                            _checkAndLoadFiles(file.path);
                          },
                  );
                }));
  }

  Future<void> _checkAndLoadFiles(String path) async {
    if (await StoragePermissions.requestPermissions()) {
      await _loadFiles(path);
    } else {
      print("Storage permission denied");
    }
  }

  Future<void> _loadFiles(String path) async {
    try {
      Directory directory = Directory(path);
      if (directory.existsSync() == false)
        throw Exception("Invalid directory path");
      List<FileSystemEntity> files = directory.listSync();
      setState(() => this.files = files);
    } catch (e) {
      print("Error loading files: $e");
    }
  }
}
