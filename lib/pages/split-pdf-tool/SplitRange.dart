import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/models/thumbnail-stats.dart';
import 'package:pdf_craft/models/thumbnail.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/SplitItem.dart';
import 'package:pdfx/pdfx.dart';

class SplitPdfRange extends StatefulWidget {
  final File file;
  final String? outFileName;
  final SplitType type;
  final Function(List<RangeModel> rgs) onRangeChange;

  const SplitPdfRange({super.key, required this.file, this.outFileName,required this.type, required this.onRangeChange}):assert(type!=SplitType.EXTRACT_ALL_PAGES);

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
      if(widget.type==SplitType.FIXED_RANGE) initNextRanges();
    }));
    if(widget.type==SplitType.FIXED_RANGE) controller.addListener(() => _tryRenderingNextThumbnails());
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
                  NotificationService.showSnackbar(text: "Split Successfull",color: Colors.green);
                  final file=httpState?.extras?['savedFile'];
                  if(file is! File) return;
                  OpenFile.open(file.path,type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(file)]??'*/*');
                }else if(httpState?.error!=null){
                  NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
                }else if(httpState?.loading==true){
                  NotificationService.showSnackbar(text: "Started Splitting",color: Colors.lightBlue);
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
              else Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Flexible(
                          child: TextFormField(keyboardType: TextInputType.number,
                              decoration: InputDecoration(label: Text("from"),border: OutlineInputBorder()),
                              controller: rangeStart,
                              validator: (value){
                                return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                              }),
                        ),
                        SizedBox(width: 12,),
                        Flexible(
                          child: TextFormField(keyboardType: TextInputType.number,
                              decoration: InputDecoration(label: Text("To"),border: OutlineInputBorder()),
                              controller: rangeEnd,
                              validator: (value){
                                return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                              }),
                        ),
                      ],
                    ),
                    SizedBox(height: 12,),
                    FilledButton(onPressed: document==null ? null : (){
                      final from= min(int.tryParse(rangeStart.text) ?? 1, document!.pagesCount)-1;
                      final to=min(int.tryParse(rangeEnd.text) ?? 1, document!.pagesCount)-1;
                      if(from<0 || to<0) return;
                      _addRange(RangeModel(from:from, to:to ));
                    }, child: Text("Add Range")),
                  ],
                ),
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
                    child: SplitItem(onDelete: widget.type!=SplitType.FIXED_RANGE ? ()=>_removeRange(range):null,range:range,startThumbnail: _thumbnailsCache[range.from+1]!,endThumbnail: range.from==range.to ? null : _thumbnailsCache[range.to+1],),
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
      if(from>=document!.pagesCount) return;
      await _tryLoadingRange(document!, from, to);
      _pageRanges.add(RangeModel(from: from, to: to));
    }
  }

  _tryLoadingRange(PdfDocument document,int from,int to)async{
    await _loadThumbnail(document: document, pageNo: from+1);
    if(from!=to) await _loadThumbnail(document: document, pageNo: to+1);
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
        format: PdfPageImageFormat.jpeg
      );
      await page.close();
      return image;
    } catch (e) {
      throw Exception("Failed to load pdf page");
    }
  }

  _addRange(RangeModel rangeNew) async{//this from,to are real pageNo
    if(rangeNew.from>rangeNew.to) return;
    await _tryLoadingRange(document!, rangeNew.from, rangeNew.to);
    setState(()=>_pageRanges=_mergeGroups(_pageRanges..add(rangeNew)));
    widget.onRangeChange(_pageRanges);
  }

  _removeRange(RangeModel range){
    setState(()=>_pageRanges.removeWhere((xrange)=>xrange.from==range.from && xrange.to==range.to));
    widget.onRangeChange(_pageRanges);
  }

  void _onReorderPages() async {
  }

  @override
  void dispose() {
    _pdfController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onFixedRangeChange(String? value) {
    if(value==null || (int.tryParse(value) ?? 0)<1) return;
    Timer.run(() => setState((){
      fixedRange=int.tryParse(value) ?? 1;
      widget.onRangeChange([RangeModel(from: fixedRange, to: fixedRange)]);
      initNextRanges();
    }));
  }

  List<RangeModel> _mergeGroups(List<RangeModel> ranges){
    ranges.sort((a, b) => (a.from<b.from) ? a.from-b.from : a.to-b.to);

    List<RangeModel> mergedRanges=[];
    for(final range in ranges){
      if(mergedRanges.isEmpty){
        mergedRanges.add(range);
        continue;
      }
      final topR=mergedRanges.last;
      if(range.from<=topR.to) {
        mergedRanges.removeLast();
        mergedRanges.add(RangeModel(from: topR.from, to: max(range.to, topR.to)));
      }else{
        mergedRanges.add(range);
      }
    }
    return mergedRanges;
  }
}

