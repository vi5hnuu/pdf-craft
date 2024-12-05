import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdfx/pdfx.dart';

class Thumbnail{
  bool? isLoading;
  String? error;
  PdfPageImage? image;

  Thumbnail({this.isLoading,this.error,this.image});
}

class ThumbnailStats{
  int loadingCount;
  int errorCount;
  int fetchedCount;

  ThumbnailStats({required this.loadingCount,required this.errorCount,required this.fetchedCount});
}

class SplitPdfRange extends StatefulWidget {
  final File file;
  final String? outFileName;
  final SplitType type;

  const SplitPdfRange({super.key, required this.file, this.outFileName,required this.type}):assert(type!=SplitType.EXTRACT_ALL_PAGES);

  @override
  State<SplitPdfRange> createState() => _SplitPdfRangeState();
}

class _SplitPdfRangeState extends State<SplitPdfRange> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  final TextEditingController rangeStart=TextEditingController();
  final TextEditingController rangeEnd=TextEditingController();
  final int pageSize=10;
  int fixedRange=10;
  final ScrollController controller=ScrollController();
  final Map<int,Thumbnail> _thumbnailsCache={};
  late final PdfDocument? document;
  late PdfController _pdfController;
  List<RangeModel> _pageRanges=[];
  int? draggingItemIndex;

  @override
  void initState() {
    _pdfController = PdfController(document: PdfDocument.openFile(widget.file.path),initialPage: 1);
    _pdfController.document.then((doc)=>setState((){
      if(!mounted) return;
      document=doc;
      initNextRanges();
    }));
    controller.addListener(() => _tryRenderingNextThumbnails());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final md=MediaQuery.of(context);

    return FutureBuilder(future: _pdfController.document, builder: (context, snapshot) {
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
        return BlocListener<PdfBloc,PdfState>(
            listenWhen: (previous, current) => previous.httpStates[HttpStates.REORDER_PDF]!=current.httpStates[HttpStates.REORDER_PDF],
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
            ,child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if(widget.type==SplitType.FIXED_RANGE) Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Fixed range",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                  SizedBox(width: 12),
                  Flexible(
                    child: TextFormField(keyboardType: TextInputType.number,
                        decoration: InputDecoration(border: OutlineInputBorder()),
                        onChanged: (value) => setState(()=>fixedRange=int.tryParse(value) ?? 1),
                        validator: (value){
                          return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                        }),
                  ),
                ])
            else Column(
              children: [
                Row(
                  children: [
                    TextFormField(keyboardType: TextInputType.number,
                        decoration: InputDecoration(label: Text("from"),border: OutlineInputBorder()),
                        controller: rangeStart,
                        validator: (value){
                          return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                        }),
                    SizedBox(width: 12,),
                    TextFormField(keyboardType: TextInputType.number,
                        decoration: InputDecoration(label: Text("To"),border: OutlineInputBorder()),
                        controller: rangeEnd,
                        validator: (value){
                          return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                        }),
                  ],
                ),
                FilledButton(onPressed: ()=>_addRange(RangeModel(from: int.parse(rangeStart.text), to: int.parse(rangeEnd.text))), child: Text("Add Range")),
              ],
            ),
            SizedBox(height: 16),
            Expanded(child: ListView.builder(itemCount: _pageRanges.length,
              itemBuilder: (context, index){
                final range=_pageRanges[index];
                return SplitItem(startThumbnail: _thumbnailsCache[range.from]!,endThumbnail: _thumbnailsCache[range.to],);
              })),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(onPressed: _onReorderPages, child: const Text("Reorder Pdf Pages")),
            )
          ],
        ));
      }
    );
  }

  initNextRanges() async {
    if(document==null) throw Exception("Document is not initialized");
    if(!mounted) return;

    //reset ranges if fixed-range changed
    if(_pageRanges.isNotEmpty && (_pageRanges.first.to-_pageRanges.first.from)!=fixedRange) setState(()=>_pageRanges.clear());

    await _reloadErroredThumbnails(document!);
    var stats=_thumbnailsStats();
    if(stats.loadingCount/(stats.loadingCount+stats.fetchedCount+stats.errorCount)>0.8) return;

    int nextPageRangeIndex=_pageRanges.length+1;
    for(int rangeStart=nextPageRangeIndex;rangeStart<nextPageRangeIndex+pageSize;rangeStart++){
      int from=rangeStart*pageSize;
      int to=min(from+pageSize, document!.pagesCount)-1;
      _pageRanges.add(RangeModel(from: from, to: to));
      await _loadThumbnail(document: document!, pageNo: from);
      if(from!=to) await _loadThumbnail(document: document!, pageNo: to);
      if(from>=document!.pagesCount) return;
    }
  }

  _tryRenderingNextThumbnails() async {
    if(document==null) return;

    if(!controller.hasClients) return;
    final maxScroll=controller.position.maxScrollExtent;
    final scrollPixels=controller.position.pixels;
    final percentScroll= (scrollPixels/maxScroll)*100;
    if(percentScroll<90) return;
    await initNextRanges();
  }

  _reloadErroredThumbnails(PdfDocument document) async{
    for(final errorThubnails in _errorThumbnails()){
      await _loadThumbnail(document: document, pageNo: errorThubnails.key);
    }
  }

  ThumbnailStats _thumbnailsStats(){
    var thumbnailStats=ThumbnailStats(loadingCount: 0, errorCount: 0, fetchedCount: 0);

    for(var range in _pageRanges){
      if(_thumbnailsCache[range.from]?.isLoading==true) thumbnailStats.loadingCount++;
      else if(_thumbnailsCache[range.from]?.error!=null) thumbnailStats.errorCount++;
      else if(_thumbnailsCache[range.from]?.image!=null) thumbnailStats.fetchedCount++;

      if(range.from!=range.to && _thumbnailsCache[range.to]?.isLoading==true) thumbnailStats.loadingCount++;
      if(range.from!=range.to && _thumbnailsCache[range.to]?.error!=null) thumbnailStats.errorCount++;
      if(range.from!=range.to && _thumbnailsCache[range.to]?.image!=null) thumbnailStats.fetchedCount++;
    }
    return thumbnailStats;
  }

  List<MapEntry<int,Thumbnail>> _errorThumbnails(){
    List<MapEntry<int,Thumbnail>> errorThumbnails=[];
    for(var range in _pageRanges){
      if(_thumbnailsCache[range.from]?.error!=null) errorThumbnails.add(MapEntry(range.from,_thumbnailsCache[range.from]!));
      if(range.from!=range.to && _thumbnailsCache[range.to]?.error!=null) errorThumbnails.add(MapEntry(range.to,_thumbnailsCache[range.to]!));
    }
    return errorThumbnails;
  }

  _loadThumbnail({required PdfDocument document,required int pageNo}) async{
    if(_thumbnailsCache[pageNo]?.image!=null || _thumbnailsCache[pageNo]?.isLoading==true) return;
    try{
      setState((){
        if(mounted) _thumbnailsCache.put(pageNo, Thumbnail(isLoading: true));
      });
      final PdfPageImage? image=await _loadPageImage(document: document, pageNumber: pageNo);
      if(image==null) throw Exception();
      setState((){
        if(mounted) _thumbnailsCache.put(pageNo, Thumbnail(image: image));
      });
    }catch(e){
      setState((){
        if(mounted) _thumbnailsCache.put(pageNo, Thumbnail(error: "failed to render thumbnail"));
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

  _addRange(RangeModel rangeNew){
    for(int rIdx=0;rIdx<_pageRanges.length;rIdx++){
      final xrange=_pageRanges[rIdx];

      if(xrange.to>=rangeNew.from && (rIdx+1<_pageRanges.length && _pageRanges[rIdx+1].from<=rangeNew.to)){
        NotificationService.showSnackbar(text: "Invalid range (collision)",color: Colors.red);
        return;
      }
      else if(xrange.to<rangeNew.from && (rIdx+1>=_pageRanges.length || _pageRanges[rIdx+1].from>rangeNew.to)){
        setState(() {
          if(rIdx+1>=_pageRanges.length) _pageRanges.add(rangeNew);
          else _pageRanges.insert(rIdx+1, rangeNew);
        });
      }
    }
  }

  _removeRange(RangeModel range){
    setState(()=>_pageRanges.removeWhere((xrange)=>xrange.from==range.from && xrange.to==range.to));
  }

  void _onReorderPages() async {
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }
}

class SplitItem extends StatelessWidget {
  final Thumbnail startThumbnail;
  final Thumbnail? endThumbnail;

  const SplitItem({
    super.key,
    required this.startThumbnail,
    required this.endThumbnail
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 2),
      child: Flex(
        direction: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200*1.14,
            width: 200,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey),borderRadius: BorderRadius.circular(8)),
            child: (startThumbnail!.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (startThumbnail.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(startThumbnail.image!.bytes,fit: BoxFit.fitWidth,)),
          ),
          if(endThumbnail!=null) Text("..."),
          if(endThumbnail!=null) Container(
            height: 200*1.14,
            width: 200,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey),borderRadius: BorderRadius.circular(8)),
            child: (startThumbnail!.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (startThumbnail.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(startThumbnail.image!.bytes,fit: BoxFit.fitWidth,)),
          )
        ],
      ),
    );;
  }
}
