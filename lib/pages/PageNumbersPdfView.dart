import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

class PageNumberPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  PageNumberPdfView({super.key, required this.file, this.outFileName});

  @override
  State<PageNumberPdfView> createState() => _PageNumberPdfViewState();
}

class _PageNumberPdfViewState extends State<PageNumberPdfView> {
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
        title: Text('Reorder Pdf Pages'),
        elevation: 5,
      ),
      body: FutureBuilder(future: _pdfController.document, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: const Center(child: Icon(Icons.error, color: Colors.red)),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: ReorderableListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              onReorder: _reorder,
              scrollDirection: Axis.vertical,
              itemCount: snapshot.data!.pagesCount,
              header: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: RichText(
                  text: const TextSpan(
                    text: 'Reorder Pages ',
                    style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '( long press to drag )',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              onReorderStart: (index)=>setState(()=>draggingItemIndex=index),
              onReorderEnd: (index)=>setState(()=>draggingItemIndex=null),
              itemBuilder: (context, index) {
                return Padding(
                  key: ValueKey('page-$index}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      PdfPageThumbnail(document: snapshot.data!, pageNumber: _pageIndexes[index]+1, width: 100, height: 200),
                      Text(Utility.fileName(file: widget.file)),
                      Text('Page ${_pageIndexes[index]+1}'),
                    ],
                  ),
                );
              },
            )),
            FilledButton(onPressed: (){}, child: const Text("Reorder Pdf Pages"))
          ],
        );
      },) ,
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
}
