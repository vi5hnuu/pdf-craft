import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pdf_craft/widgets/tool_error_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/extensions/map_entensions.dart';
import 'package:pdf_craft/models/enums/split_type.dart';
import 'package:pdf_craft/models/request/split_pdf.dart';
import 'package:pdf_craft/models/thumbnail_stats.dart';
import 'package:pdf_craft/models/thumbnail.dart';
import 'package:pdf_craft/utils/debouncer.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/widgets/split_item.dart';
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
  final Debouncer _scrollDebounce=Debouncer(milliseconds: 120);
  /// Rendered page thumbnails, keyed by 1-based page number.
  ///
  /// Deliberately uncapped: nothing reloads an evicted entry here — loading is driven by
  /// *new* ranges — so an LRU left scrolled-past rows permanently blank, and the zero-height
  /// rows that produced kept the scroll pinned at the end, which appended batch after batch.
  /// The memory it was defending against is already gone: these render at the 150dp they are
  /// drawn at rather than the page's intrinsic size.
  final Map<int,Thumbnail> _thumbnailsCache={};

  /// Width, in logical pixels, the thumbnails are actually painted at (see SplitItem).
  /// Rendering at the page's intrinsic size produced bitmaps many times larger than needed.
  static const double _thumbnailWidth=150;

  // Deliberately not `late final`: it is assigned in an async callback, and the scroll
  // listener installed in initState reads it before that completes. A late field read before
  // assignment throws LateInitializationError, so the `document == null` guards below could
  // never actually run — scrolling a large PDF before it opened crashed instead.
  PdfDocument? document;
  late PdfController _pdfController;
  List<RangeModel> _pageRanges=[];
  int? draggingItemIndex;

  @override
  void initState() {
    _pdfController = PdfController(document: PdfDocument.openFile(widget.file.path),initialPage: 1);
    _pdfController.document.then((doc){
      // Outside setState: setState dereferences the element before it runs the callback, so a
      // check inside it is dead code and popping this screen while the document opened threw.
      if(!mounted){
        doc.close();
        return;
      }
      setState((){
        document=doc;
        if(widget.type==SplitType.FIXED_RANGE) initNextRanges();
      });
    });
    // Debounced: _tryRenderingNextThumbnails awaits a reload and walks the whole cache, and
    // this fired on every scroll tick.
    if(widget.type==SplitType.FIXED_RANGE) {
      controller.addListener(() => _scrollDebounce.run(_tryRenderingNextThumbnails));
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder(future: _pdfController.document, builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return ToolErrorState(
                message: snapshot.error?.toString(), onRetry: () => setState(() {}));
          }
          // No BlocListener on HttpStates.reorderPdf here. This screen dispatches nothing, so
          // that listener only ever fired on *another* screen's reorder result — announcing it
          // and opening its file while the user sat here. Now that delete, extract, reverse and
          // organize each report under their own key, nothing emits it at all.
          return Form(
            key: _formKey,
            child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              if(widget.type==SplitType.FIXED_RANGE) Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: L10n.of(context).rangeLabel,border: const OutlineInputBorder()),
                    onChanged: _onFixedRangeChange,
                    validator: _positivePage),
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
                              decoration: InputDecoration(
                                  label: Text(L10n.of(context).fromLabel),
                                  border: const OutlineInputBorder()),
                              controller: rangeStart,
                              validator: _positivePage),
                        ),
                        const SizedBox(width: 12,),
                        Flexible(
                          child: TextFormField(keyboardType: TextInputType.number,
                              decoration: InputDecoration(label: Text(L10n.of(context).toLabel),border: const OutlineInputBorder()),
                              controller: rangeEnd,
                              validator: _positivePage),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12,),
                    FilledButton(onPressed: document==null ? null : (){
                      if (_formKey.currentState?.validate() != true) return;
                      final from= min(int.tryParse(rangeStart.text) ?? 1, document!.pagesCount)-1;
                      final to=min(int.tryParse(rangeEnd.text) ?? 1, document!.pagesCount)-1;
                      if(from<0 || to<0) return;
                      _addRange(RangeModel(from:from, to:to ));
                    }, child: Text(L10n.of(context).addRange)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                  child: ListView.builder(
                itemCount: _pageRanges.length,
                controller:controller ,
                itemBuilder: (context, index){
                  final range=_pageRanges[index];

                  final start = _thumbnailsCache[range.from+1];
                  if (start == null) return _pendingRange(range);
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SplitItem(onDelete: widget.type!=SplitType.FIXED_RANGE ? ()=>_removeRange(range):null,range:range,startThumbnail: start,endThumbnail: range.from==range.to ? null : _thumbnailsCache[range.to+1],),
                  );
                })),
            ],
          ),
          );
        }
      ),
    );
  }

  final _formKey = GlobalKey<FormState>();

  /// A page number must be a positive integer. Empty is rejected here because, unlike the
  /// image gap, there is no sensible default for "which page".
  String? _positivePage(String? value) {
    final page = int.tryParse((value ?? '').trim());
    return page != null && page > 0 ? null : L10n.current.invalidFixedRange;
  }

  /// Placeholder for a range whose first thumbnail has not arrived yet, so the list length
  /// matches the number of ranges the user actually has.
  Widget _pendingRange(RangeModel range) => Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 210,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text('${range.from + 1}-${range.to + 1}'),
            ]),
          ),
        ),
      );

  initNextRanges() async {
    if(document==null) throw Exception("Document is not initialized");
    if(!mounted) return;

    //reset ranges if fixed-range changed
    if(_pageRanges.isNotEmpty && (_pageRanges.first.to-_pageRanges.first.from+1)!=fixedRange){
      await _removeErrorThumbnails();
      if (!mounted) return;
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
    if(percentScroll<90 && _errorThumbnails().isEmpty) return;
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
      if(_thumbnailsCache[pageFrom]?.isLoading==true) {
        thumbnailStats.loadingCount++;
      } else if(_thumbnailsCache[pageFrom]?.error!=null) { thumbnailStats.errorCount++; }
      else if(_thumbnailsCache[pageFrom]?.image!=null) { thumbnailStats.fetchedCount++; }

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
      _setThumbnail(pageNo, Thumbnail(isLoading: true));
      final PdfPageImage? image=await _loadPageImage(document: document, pageNumber: pageNo);
      if(image==null) throw Exception();
      _setThumbnail(pageNo, Thumbnail(image: image));
    }catch(e){
      _setThumbnail(pageNo, Thumbnail(error: L10n.current.thumbnailFailed));
    }
  }

  /// The mounted check belongs here rather than inside setState, which asserts on a defunct
  /// element before it ever runs the callback.
  void _setThumbnail(int pageNo, Thumbnail thumbnail){
    if(!mounted) return;
    setState(()=>_thumbnailsCache.put(pageNo, thumbnail));
  }

  Future<PdfPageImage?> _loadPageImage({required PdfDocument document,required int pageNumber}) async {
    assert(pageNumber>0);

    // Read before the first await: it comes from the element's inherited widgets, which are
    // not safe to reach for once this has yielded.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    try {
      final PdfPage page = await document.getPage(pageNumber);
      // Bounded by the width it is drawn at rather than the page's own size: an A4 page at
      // intrinsic size is a multi-megabyte bitmap to fill a 150px-wide box.
      final target = _thumbnailWidth * ratio;
      final width = page.width <= target ? page.width : target;
      final PdfPageImage? image = await page.render(
        width: width,
        height: page.height / page.width * width,
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
    // Thumbnails are rendered off the main isolate, so this returns long after the tap.
    if (!mounted) return;
    setState(()=>_pageRanges=_mergeGroups(_pageRanges..add(rangeNew)));
    widget.onRangeChange(_pageRanges);
  }

  _removeRange(RangeModel range){
    setState(()=>_pageRanges.removeWhere((xrange)=>xrange.from==range.from && xrange.to==range.to));
    widget.onRangeChange(_pageRanges);
  }

  @override
  void dispose() {
    _scrollDebounce.dispose();
    rangeStart.dispose();
    rangeEnd.dispose();
    controller.dispose();
    _pdfController.dispose();
    // Disposing the controller does not close the document (see PdfPreview), so the native
    // handle and its page cache leaked on every visit to this screen.
    document?.close();
    _thumbnailsCache.clear();
    super.dispose();
  }

  void _onFixedRangeChange(String? value) {
    if(value==null || (int.tryParse(value) ?? 0)<1) return;
    Timer.run(() {
      // This had no mounted check at all, so changing the range and leaving immediately
      // called setState on a defunct element.
      if(!mounted) return;
      setState((){
        fixedRange=int.tryParse(value) ?? 1;
        widget.onRangeChange([RangeModel(from: fixedRange, to: fixedRange)]);
        initNextRanges();
      });
    });
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

