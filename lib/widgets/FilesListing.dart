import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/enums/listing-type.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';
import 'package:pdf_craft/widgets/DirectoryFilesListing.dart';

class FilesListing extends StatefulWidget {
  final ListingType type;

  const FilesListing({super.key, required this.type});

  @override
  State<FilesListing> createState() => _FilesListingState();
}

class _FilesListingState extends State<FilesListing> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DirectoryFilesListing(directoryPath: widget.type.path),
      ),
    );
  }
}
