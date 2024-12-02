import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/utils/utility.dart';

class RotatePdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  RotatePdfView({super.key, required this.file, this.outFileName}) {
  }

  @override
  State<RotatePdfView> createState() => _RotatePdfViewState();
}

class _RotatePdfViewState extends State<RotatePdfView> {
  int? draggingItemIndex;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Rotate Pdf'),
        elevation: 5,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children:[
        // final int file_angle; // angle at which all pages will be rotated
        // final Map<int,int> page_angles; // if a page do not have angle file angle is used else no rotation [0 index]
        // final bool maintain_ratio;//default true
        // final MultipartFile file;//default true

        ],
      ),
    );
  }
}
