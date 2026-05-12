import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

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
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  final int pageSize=10;
  final ScrollController controller=ScrollController();
  final Map<int,Thumbnail> thumbnails={};
  late final PdfDocument? document;
  late PdfController _pdfController;
  List<int> _pageIndexes=[];
  final TextEditingController outFileNameC=TextEditingController();

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    _pdfController = PdfController(document: PdfDocument.openFile(widget.file.path),initialPage: 1);
    _pdfController.document.then((doc)=>setState((){
      if(!mounted) return;
      document=doc;
      _pageIndexes=List.generate(doc.pagesCount, (index) => index);
      _tryRenderingNextThumbnails();
    }));
    controller.addListener(() => _tryRenderingNextThumbnails());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final md=MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reorder PDF Pages'), elevation: 5),
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
        return BlocConsumer<PdfBloc,PdfState>(
            listenWhen: (previous, current) => previous.httpStates[HttpStates.REORDER_PDF]!=current.httpStates[HttpStates.REORDER_PDF],
            buildWhen: (previous, current) => previous.httpStates[HttpStates.REORDER_PDF]!=current.httpStates[HttpStates.REORDER_PDF],
            listener: (context, state) {
              final httpState=state.httpStates[HttpStates.REORDER_PDF];
              if(httpState?.done==true){
                NotificationService.showSnackbar(text: "Reorder Successfull",color: Colors.green);
                if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
              }else if(httpState?.error!=null){
                NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
              }else if(httpState?.loading==true){
                NotificationService.showSnackbar(text: "Started reordering",color: Colors.lightBlue);
              }
            }
            ,builder: (context, state) {
              return Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(keyboardType: TextInputType.text,
                          decoration: InputDecoration(labelText: "Output File Name",border: OutlineInputBorder()),
                          controller: outFileNameC),
                      ),
                      Expanded(child: ReorderableListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        onReorder: _reorder,
                        scrollDirection: Axis.vertical,
                        itemCount: thumbnails.length,
                        header: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: RichText(
                            text: TextSpan(
                              text: 'Reorder Pages ',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: ' (long press to drag)',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        scrollController: controller,
                        itemBuilder: (context, index) {
                          final pageNo=_pageIndexes[index]+1;
                          final thumbnail=thumbnails[pageNo];
                          final thumbnailWidth=md.size.width*0.25;
                          final thumbnailHeight=thumbnailWidth*1.404;
                          return Padding(
                            key: ValueKey('page-$pageNo'),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 2),
                            child: Flex(
                              direction: Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: thumbnailHeight,
                                  width: thumbnailWidth,
                                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),borderRadius: BorderRadius.circular(8)),
                                  child: (thumbnail!.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (thumbnail.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(thumbnail.image!.bytes,fit: BoxFit.fitWidth,)),
                                ),
                                Flexible(child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(textAlign: TextAlign.justify,softWrap: true,maxLines: 3,Utility.fileName(file: widget.file),style: const TextStyle(overflow: TextOverflow.ellipsis,fontWeight: FontWeight.bold,fontSize: 18)),
                                      Text('Page $pageNo',style: const TextStyle(fontWeight: FontWeight.w500,fontStyle: FontStyle.italic))
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          );
                        },
                      )),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        child: FilledButton(onPressed: _onReorderPages, child: const Text("Reorder Pdf Pages")),
                      )
                    ],
                  ),
                  LoadingOverlay(httpState: state.httpStates[HttpStates.REORDER_PDF]),
                ],
              );
            },);
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

  _tryRenderingNextThumbnails() async {
    if(document==null) return;

    await _reloadErroredThumbnails(document!);

    if(thumbnails.isEmpty) {
      await _loadThumbnails();
      return;
    }
    if(!controller.hasClients) return;
    final maxScroll=controller.position.maxScrollExtent;
    final scrollPixels=controller.position.pixels;
    final percentScroll= (scrollPixels/maxScroll)*100;
    if(percentScroll<90) return;
    await _loadThumbnails();
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
    if(thumbnails[pageNo]?.image!=null || thumbnails[pageNo]?.isLoading==true) return;
    try{
      setState((){
        if(mounted) thumbnails.put(pageNo, Thumbnail(isLoading: true));
      });
      final PdfPageImage? image=await _loadPageImage(document: document, pageNumber: pageNo);
      if(image==null) throw Exception();
      setState((){
        if(mounted) thumbnails.put(pageNo, Thumbnail(image: image));
      });
    }catch(e){
      setState((){
        if(mounted) thumbnails.put(pageNo, Thumbnail(error: "failed to render thumbnail"));
      });
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

  void _onReorderPages() async {
    bloc.add(ReorderPdfEvent(reorderPdf: ReorderPdf(out_file_name: outFileNameC.text.isEmpty ? "reordered_file" : outFileNameC.text, order: _pageIndexes, file: await MultipartFile.fromFile(widget.file.path))));
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }
}
