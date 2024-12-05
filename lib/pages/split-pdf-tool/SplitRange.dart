import 'dart:async';
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
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
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

    return Expanded(
      child: FutureBuilder(future: _pdfController.document, builder: (context, snapshot) {
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
              if(widget.type==SplitType.FIXED_RANGE) Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Range',border: OutlineInputBorder()),
                    onChanged: _onFixedRangeChange,
                    validator: (value){
                      return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                    }),
              )
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
              Expanded(
                  child: ListView.builder(
                itemCount: _pageRanges.length,
                controller:controller ,
                itemBuilder: (context, index){
                  final range=_pageRanges[index];

                  if(_thumbnailsCache[range.from+1]==null) return SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SplitItem(range:range,startThumbnail: _thumbnailsCache[range.from+1]!,endThumbnail: range.from==range.to ? null : _thumbnailsCache[range.to+1],),
                  );
                })),
            ],
          ));
        }
      ),
    );
  }

  initNextRanges() async {
    if(document==null) throw Exception("Document is not initialized");
    if(!mounted) return;

    //reset ranges if fixed-range changed
    if(_pageRanges.isNotEmpty && (_pageRanges.first.to-_pageRanges.first.from+1)!=fixedRange){
      await _removeErrorThumbnails();
      setState(()=>_pageRanges.clear());
    }

    await _reloadErroredThumbnails(document!);
    var stats=_thumbnailsStats();
    if(stats.loadingCount!=0 || stats.errorCount!=0) return;

    int nextPageRangeIndex=_pageRanges.length;
    for(int rangeStart=nextPageRangeIndex;rangeStart<nextPageRangeIndex+pageSize;rangeStart++){
      int from=rangeStart*fixedRange;
      int to=min((from+fixedRange).toInt(), (document!.pagesCount).toInt())-1;
      if(from>=document!.pagesCount){
        return;
      }
      await _loadThumbnail(document: document!, pageNo: from+1);
      if(from!=to) await _loadThumbnail(document: document!, pageNo: to+1);
      _pageRanges.add(RangeModel(from: from, to: to));
    }
  }

  _tryRenderingNextThumbnails() async {
    if(document==null) return;

    if(!controller.hasClients) return;
    final maxScroll=controller.position.maxScrollExtent;
    final scrollPixels=controller.position.pixels;
    final percentScroll= (scrollPixels/maxScroll)*100;
    if(percentScroll<90 && _errorThumbnails().length==0) return;
    await initNextRanges();
  }

  _reloadErroredThumbnails(PdfDocument document) async{
    for(final errorThubnails in _errorThumbnails()){
      await _loadThumbnail(document: document, pageNo: errorThubnails.key);
    }
  }

  _removeErrorThumbnails() async{
    for(final thumbnail in _thumbnailsCache.clone().entries){
      if(thumbnail.value.error!=null) _thumbnailsCache.remove(thumbnail.key);
    }
  }

  ThumbnailStats _thumbnailsStats(){
    var thumbnailStats=ThumbnailStats(loadingCount: 0, errorCount: 0, fetchedCount: 0);

    for(var range in _pageRanges){
      final pageFrom=range.from+1;
      final pageTo=range.to+1;
      if(_thumbnailsCache[pageFrom]?.isLoading==true) thumbnailStats.loadingCount++;
      else if(_thumbnailsCache[pageFrom]?.error!=null) thumbnailStats.errorCount++;
      else if(_thumbnailsCache[pageFrom]?.image!=null) thumbnailStats.fetchedCount++;

      if(range.from!=range.to && _thumbnailsCache[pageTo]?.isLoading==true) thumbnailStats.loadingCount++;
      if(range.from!=range.to && _thumbnailsCache[pageTo]?.error!=null) thumbnailStats.errorCount++;
      if(range.from!=range.to && _thumbnailsCache[pageTo]?.image!=null) thumbnailStats.fetchedCount++;
    }
    return thumbnailStats;
  }

  List<MapEntry<int,Thumbnail>> _errorThumbnails(){
    List<MapEntry<int,Thumbnail>> errorThumbnails=[];
    for(var range in _pageRanges){
      final pageFrom=range.from+1;
      final pageTo=range.to+1;

      if(_thumbnailsCache[pageFrom]?.error!=null) errorThumbnails.add(MapEntry(pageFrom,_thumbnailsCache[pageFrom]!));
      if(range.from!=range.to && _thumbnailsCache[pageTo]?.error!=null) errorThumbnails.add(MapEntry(pageTo,_thumbnailsCache[pageTo]!));
    }
    return errorThumbnails;
  }

  _loadThumbnail({required PdfDocument document,required int pageNo}) async{
    if(_thumbnailsCache[pageNo]?.image!=null || _thumbnailsCache[pageNo]?.isLoading==true) return;
    // LoggerSingleton().logger.i("Loading thumbnail for pageNo : $pageNo");
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

  void _onFixedRangeChange(String? value) {
    if(value==null || int.parse(value)<1) return;
    Timer.run(() => setState((){
      fixedRange=int.tryParse(value) ?? 1;
      initNextRanges();
    }));
  }
}

class SplitItem extends StatelessWidget {
  final pageWidth=150.0;
  final RangeModel range;
  final Thumbnail startThumbnail;
  final Thumbnail? endThumbnail;

  const SplitItem({
    super.key,
    required this.range,
    required this.startThumbnail,
    required this.endThumbnail
  });

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: pageWidth*1.4,
          width: pageWidth,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey),borderRadius: BorderRadius.circular(8)),
          child: (startThumbnail.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (startThumbnail.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(startThumbnail.image!.bytes,fit: BoxFit.fitWidth,)),
        ),
        if(endThumbnail!=null) Column(
          children: [
            Text("${range.from+1}-${range.to+1}"),
            SizedBox(width: 50,child: Container(height: 2,decoration: BoxDecoration(color: Colors.white),),)
          ],
        ),
        if(endThumbnail!=null) Container(
          height: pageWidth*1.4,
          width: pageWidth,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey),borderRadius: BorderRadius.circular(8)),
          child: (endThumbnail!.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (endThumbnail!.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(endThumbnail!.image!.bytes,fit: BoxFit.fitWidth,)),
        )
      ],
    );;
  }
}
