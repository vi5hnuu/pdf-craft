import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

class Thumbnail{
  bool? isLoading;
  String? error;
  PdfPageImage? image;

  Thumbnail({this.isLoading,this.error,this.image});
}

class ReorderPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  const ReorderPdfView({super.key, required this.file, this.outFileName});

  @override
  State<ReorderPdfView> createState() => _ReorderPdfViewState();
}

class _ReorderPdfViewState extends State<ReorderPdfView> {
  final int pageSize=20;
  final ScrollController controller=ScrollController();
  final Map<int,Thumbnail> thumbnails={};
  late final PdfDocument? document;
  late PdfController _pdfController;
  List<int> _pageIndexes=[];
  int? draggingItemIndex;

  @override
  void initState() {
    _pdfController = PdfController(document: PdfDocument.openFile(widget.file.path),initialPage: 1);
    _pdfController.document.then((doc)=>setState((){
      document=doc;
      _tryRenderingNextThumbnails();
    }));
    controller.addListener(() => _tryRenderingNextThumbnails());
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
              itemCount: thumbnails.length,
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
              scrollController: controller,
              itemBuilder: (context, index) {
                final pageNo=_pageIndexes[index]+1;
                final thumbnail=thumbnails[pageNo];
                return Padding(
                  key: ValueKey('page-${pageNo}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 2),
                  child: Row(
                    key: ValueKey(pageNo),
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Column(
                          children: [
                            if(thumbnail!.isLoading==true) CircularProgressIndicator()
                            else if(thumbnail!.error!=null) Icon(Icons.error)
                            else Image.memory(thumbnail.image!.bytes)
                          ],
                        ),
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

  _tryRenderingNextThumbnails() async {
    if(document==null) return;

    await _reloadErroredThumbnails(document!);

    if(thumbnails.isEmpty) {
      _loadThumbnails();
      return;
    }
    if(!controller.hasClients) return;
    final maxScroll=controller.position.maxScrollExtent;
    final scrollPixels=controller.position.pixels;
    final percentScroll= (scrollPixels/maxScroll)*100;
    if(percentScroll<90) return;
  }

  _reloadErroredThumbnails(PdfDocument document) async{
    //reload error thumbnails
    for(final errorThubnails in _errorThumbnails()){
      await _loadThumbnail(document: document, pageNo: errorThubnails.key);
    }
  }

  _loadThumbnails() async{
    if(document==null) throw Exception("Document not yet initialized");

    final loadingCount=_loadingCount();
    if((loadingCount/pageSize)*100>80) return;//loading thumbnails percent > 80%

    final totalThumbnails=thumbnails.length;
    for(var thumbnailIndex=totalThumbnails;thumbnailIndex<totalThumbnails+pageSize && thumbnailIndex<document!.pagesCount;thumbnailIndex++){
      await _loadThumbnail(document: document!, pageNo: thumbnailIndex+1);
    }
  }

  _loadingCount(){
    return thumbnails.entries.where((thumbnail) => thumbnail.value.isLoading==true).length;
  }
  List<MapEntry<int,Thumbnail>> _errorThumbnails(){
    return thumbnails.entries.where((thumbnail) => thumbnail.value.error!=null).toList();
  }

  _loadThumbnail({required PdfDocument document,required int pageNo}) async{
    try{
      thumbnails.put(pageNo, Thumbnail(isLoading: true));
      final PdfPageImage? image=await _loadPageImage(document: document!, pageNumber: pageNo);
      if(image==null) throw Exception();
      thumbnails.put(pageNo, Thumbnail(image: image));
    }catch(e){
      thumbnails.put(pageNo, Thumbnail(error: "failed to render thumbnail"));
    }
  }

  Future<PdfPageImage?> _loadPageImage({required PdfDocument document,required int pageNumber}) async {
    assert(pageNumber>0);

    try {
      final PdfPage page = await document.getPage(pageNumber);
      final PdfPageImage? image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,  // Adjust the format if needed
      );
      await page.close();
      return image;
    } catch (e) {
      throw Exception("Failed to load pdf page");
    }
  }
}
