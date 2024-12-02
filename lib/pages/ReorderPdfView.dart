import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

class ReorderPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  const ReorderPdfView({super.key, required this.file, this.outFileName});

  @override
  State<ReorderPdfView> createState() => _ReorderPdfViewState();
}

class _ReorderPdfViewState extends State<ReorderPdfView> {
  static final Map<int,Widget> _thumbnailCache={};

  late PdfController _pdfController;
  List<int> _pageIndexes=[];
  int? draggingItemIndex;

  @override
  void initState() {
    _pdfController = PdfController(document: PdfDocument.openFile(widget.file.path),initialPage: 1);
    _pdfController.document.then((doc)=>setState((){
      _pageIndexes=List.generate(doc.pagesCount, (index) => index);
    }));
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
            Expanded(child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              scrollDirection: Axis.vertical,
              itemCount: snapshot.data!.pagesCount,
              itemBuilder: (context, index) {
                final pageNo=_pageIndexes[index]+1;
                if(!_thumbnailCache.containsKey(pageNo)) _thumbnailCache.put(pageNo, PdfPageThumbnail(key: ValueKey(pageNo),document: snapshot.data!, pageNumber: _pageIndexes[index]+1, width: 100, height: 200));
                return Padding(
                  key: ValueKey('page-${pageNo}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 2),
                  child: Row(
                    key: ValueKey(pageNo),
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(width: 100,height: 100,child: _thumbnailCache[pageNo]),
                      Text(Utility.fileName(file: widget.file),style: TextStyle(color: Colors.black),),
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

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }
}
