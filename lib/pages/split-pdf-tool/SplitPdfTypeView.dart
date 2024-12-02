import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

class SplitPdfTypeView extends StatefulWidget {
  final File file;
  final String outFileName;
  final SplitType type;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  SplitPdfTypeView({super.key, required this.file,required this.outFileName,required this.type});

  @override
  State<SplitPdfTypeView> createState() => _SplitPdfTypeViewState();
}

class _SplitPdfTypeViewState extends State<SplitPdfTypeView> {
  late PdfControllerPinch _pdfController;
  List<int> _pageIndexes=[];
  int? draggingItemIndex;

  @override
  void initState() {
    _pdfController = PdfControllerPinch(document: PdfDocument.openFile(widget.file.path),initialPage: 1);
    _pdfController.document.then((doc)=>setState(()=>_pageIndexes=List.generate(doc.pagesCount, (index) => index)));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Spliting By -${widget.type.type.capitalize()}-'),
        elevation: 5,
      ),
      body: Column(
        children: [
          if(_pageIndexes.isNotEmpty) Text("Total pages : ${_pageIndexes.length}"),
          if(widget.type==SplitType.SPLIT_BY_RANGE) _buildSplitByRangeView()
          else if(widget.type==SplitType.FIXED_RANGE) _buildFixedRangeView()
          else if(widget.type==SplitType.DELETE_PAGES) _buildDeletePagesView(),
          FilledButton(onPressed: (){}, child: Text("Split Pdf"))
        ],
      ),
    );
  }

  void _reorder(oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final int removedPageIndex = _pageIndexes.removeAt(oldIndex);
      _pageIndexes.insert(newIndex, removedPageIndex);
    });
  }

  _getInterval({required String title}) {
    showGeneralDialog(context: context, pageBuilder: (context, animation, secondaryAnimation) {
      return Container(
        child: Column(
          children: [
            Text(title),
            TextFormField(),
            FilledButton(onPressed: (){}, child: Text("Done"))
          ],
        ),
      );
    });
  }

  _buildFixedRangeView() {
    return Column(
      children: [
        Text("Fixed range"),
        ListTile(
          onTap: ()=> _getInterval(title: "Fixed range"),
          title: Text("Split document into equal page ranges"),
          subtitle: Text("5"),
        )
      ],
    );
  }

  _buildDeletePagesView() {
    return Column(
      children: [
        Text("Delete ranges"),
        Column(
          children: [
            ListTile(onTap:()=> _getInterval(title:"From page no" ),title: Text("From page number"),subtitle: Text("1"),),
            ListTile(onTap:()=> _getInterval(title: "To page no" ),title: Text("To page number"),subtitle: Text("2"),)
          ],
        ),
        TextButton(onPressed: (){}, child: Text("Add range"))
      ],
    );
  }

  _buildSplitByRangeView() {
    return Column(
      children: [
        Text("Split by range"),
        Column(
          children: [
            ListTile(onTap:()=> _getInterval(title:"From page no" ),title: Text("From page number"),subtitle: Text("1"),),
            ListTile(onTap:()=> _getInterval(title: "To page no" ),title: Text("To page number"),subtitle: Text("2"),)
          ],
        ),
        TextButton(onPressed: (){}, child: Text("Add range"))
      ],
    );
  }
}

