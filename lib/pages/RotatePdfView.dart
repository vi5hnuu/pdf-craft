import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/map-entensions.dart';
import 'package:pdf_craft/models/request/reorder-pdf.dart';
import 'package:pdf_craft/models/request/rotate-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/RotatableItem.dart';
import 'package:pdfx/pdfx.dart';

class Thumbnail{
  bool? isLoading;
  String? error;
  PdfPageImage? image;

  Thumbnail({this.isLoading,this.error,this.image});
}

class RotatePdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  const RotatePdfView({super.key, required this.file, this.outFileName});

  @override
  State<RotatePdfView> createState() => _RotatePdfViewState();
}

class _RotatePdfViewState extends State<RotatePdfView> {
  TextEditingController pageNo=TextEditingController();
  TextEditingController pageAngle=TextEditingController();
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  final int pageSize=10;
  final ScrollController controller=ScrollController();
  final Map<int,Thumbnail> thumbnails={};
  late final PdfDocument? document;
  late PdfController _pdfController;
  List<int> _pageIndexes=[];
  int file_angle=0; // angle at which all pages will be rotated
  Map<int,int> page_angles={}; // if a page do not have angle, file angle is used else no rotation [0 index]
  bool maintain_ratio=true;//default true

  @override
  void initState() {
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
      backgroundColor: Colors.black,
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
        return BlocListener<PdfBloc,PdfState>(
            listenWhen: (previous, current) => previous.httpStates[HttpStates.ROTATE_PDF]!=current.httpStates[HttpStates.ROTATE_PDF],
            listener: (context, state) {
              final httpState=state.httpStates[HttpStates.ROTATE_PDF];
              if(httpState?.done==true){
                NotificationService.showSnackbar(text: "Rotate Successfull",color: Colors.green);
                if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
              }else if(httpState?.error!=null){
                NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
              }else if(httpState?.loading==true){
                NotificationService.showSnackbar(text: "Started Rotating",color: Colors.lightBlue);
              }
            }
            ,child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  TextFormField(keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "All page angle",border: OutlineInputBorder()),
                      onChanged: (value) => setState(()=>file_angle=int.tryParse(value) ?? 0)),
                  Text("All pages will be rotate at this angle, to change angle for specific pages add range below",style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Text("Maintain Aspect Ratio ",style: TextStyle(fontSize: 20),),
                  SizedBox(width: 16,),
                  Switch(value: maintain_ratio, onChanged: (value)=>setState(() =>maintain_ratio=value))
                ],
              ),
            ),
            Text("All pages with render without overlap, below view is not exactly correct"),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: TextFormField(keyboardType: TextInputType.number,
                            decoration: InputDecoration(label: Text("PageNo"),border: OutlineInputBorder()),
                            controller: pageNo,
                            validator: (value){
                              return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                            }),
                      ),
                      SizedBox(width: 12,),
                      Flexible(
                        child: TextFormField(keyboardType: TextInputType.number,
                            decoration: InputDecoration(label: Text("Angle(0,360)"),border: OutlineInputBorder()),
                            controller: pageAngle,
                            validator: (value){
                              return value!=null && (int.parse(value)>0) ? null : "Invalid fixed range";
                            }),
                      ),
                    ],
                  ),
                  SizedBox(height: 12,),
                  FilledButton(onPressed: document==null ? null : (){
                    final pNo= int.tryParse(pageNo.text);
                    final anglr=int.tryParse(pageAngle.text);
                    if(pNo==null || pNo<=0 || pNo>document!.pagesCount){
                      NotificationService.showSnackbar(text: "Invalid pageNo",color: Colors.red);
                      return;
                    }
                    if(anglr==null || anglr<=0 || anglr>360){
                      NotificationService.showSnackbar(text: "Invalid angle (0,360)",color: Colors.red);
                      return;
                    }
                    setState(()=>page_angles.put(pNo,anglr));
                    pageNo.clear();
                    pageAngle.clear();
                  }, child: Text("Add Range")),
                  SizedBox(height: 18,),
              Wrap(
                spacing: 8.0, // Space between chips horizontally
                runSpacing: 8.0, // Space between chips vertically
                children: page_angles.entries.map((range) {
                  return Flexible(
                    child: Chip(
                      onDeleted: () => setState(()=>page_angles.remove(range.key)),
                      label: Text(
                        "Page ${range.key} : ${range.value}°",
                        style: TextStyle(color: Colors.black),
                        overflow: TextOverflow.ellipsis, // Ensure text truncates if too long
                        maxLines: 1, // Ensure text remains on one line
                      ),
                      backgroundColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
                ],
              ),
            ),
            Expanded(child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              scrollDirection: Axis.vertical,
              itemCount: thumbnails.length,
              itemBuilder: (context, index) {
                final pageNo=_pageIndexes[index]+1;
                final thumbnail=thumbnails[pageNo];
                final thumbnailWidth=md.size.width*0.45;
                final thumbnailHeight=thumbnailWidth*1.37;
                return Padding(
                  key: ValueKey('page-$pageNo'),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 8),
                  child: Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotatablePageWidget(originalWidth: thumbnailWidth, originalHeight: thumbnailHeight, maintainAspectRatio: maintain_ratio, rotationAngle: (page_angles[index+1] ?? file_angle).toDouble(), child: Container(
                        height: thumbnailHeight,
                        width: thumbnailWidth,
                        child: (thumbnail!.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (thumbnail.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(thumbnail.image!.bytes,fit: BoxFit.contain,)),
                      ))
                    ],
                  ),
                );
              },
            )),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: FilledButton(onPressed: _onRotatePages, child: const Text("Rotate Pdf Pages")),
            )
          ],
        ));
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

  void _onRotatePages() async {
    bloc.add(RotatePdfEvent(rotatePdf: RotatePdf(out_file_name: "out_file_name", file_angle: file_angle,maintain_ratio: maintain_ratio,page_angles: page_angles, file: await MultipartFile.fromFile(widget.file.path))));
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }
}