import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

class SplitPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  SplitPdfView({super.key, required this.file,this.outFileName});

  @override
  State<SplitPdfView> createState() => _SplitPdfViewState();
}

class _SplitPdfViewState extends State<SplitPdfView> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final router=GoRouter.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Split Pdf'),
        elevation: 5,
      ),
      body: Column(
        children: [
          ListTile(onTap: ()=>router.pushNamed(AppRoutes.splitByTypePdfRoute.name,pathParameters: {'splitType':SplitType.SPLIT_BY_RANGE.type}),title: Text("Split by ranges"),subtitle: Text("Add custom ranges"),),
          ListTile(onTap: ()=>router.pushNamed(AppRoutes.splitByTypePdfRoute.name,pathParameters: {'splitType':SplitType.FIXED_RANGE.type}),title: Text("Fixed ranges"),subtitle: Text("Assign a fixed range"),),
          ListTile(onTap: ()=>router.pushNamed(AppRoutes.splitByTypePdfRoute.name,pathParameters: {'splitType':SplitType.DELETE_PAGES.type}),title: Text("Delete pages"),subtitle: Text("Remove individual pages or range of pages"),),
          ListTile(trailing: Checkbox(value: true, onChanged: (value) {}),title: Text("Extract all pages"),subtitle: Text("Every page will be converted to a seperate PDF file, a total of 19 PDF will be generated"),),
        ],
      ) ,
    );
  }
}
