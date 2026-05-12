import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';

class ImageToPdfView extends StatefulWidget {
  final List<File> files;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  ImageToPdfView({super.key, required this.files, this.outFileName});

  @override
  State<ImageToPdfView> createState() => _ImageToPdfViewState();
}

class _ImageToPdfViewState extends State<ImageToPdfView> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  final TextEditingController outFileNameC=TextEditingController();

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final md=MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Image to PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc,PdfState>(
          buildWhen: (previous, current) => previous.httpStates[HttpStates.IMAGE_TO_PDF]!=current.httpStates[HttpStates.IMAGE_TO_PDF],
          listenWhen: (previous, current) => previous.httpStates[HttpStates.IMAGE_TO_PDF]!=current.httpStates[HttpStates.IMAGE_TO_PDF],
          listener: (context, state) {
        final httpState=state.httpStates[HttpStates.IMAGE_TO_PDF];
        if(httpState?.done==true){
          NotificationService.showSnackbar(text: "Image to pdf successfull",color: Colors.green);
          if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
        }else if(httpState?.error!=null){
          NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
        }else if(httpState?.loading==true){
          NotificationService.showSnackbar(text: "Started converting image/s to pdf",color: Colors.lightBlue);
        }
      },builder: (context, state) {
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
                  itemCount: widget.files.length,
                  header: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Reorder File ',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: '( long press to drag )',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final file = widget.files[index];
                    return Padding(
                        key: ValueKey(file.path),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 6),
                        child: Flex(
                          direction: Axis.horizontal,
                          children: [
                            Image.file(file,width: md.size.width*0.25,fit: BoxFit.fitWidth,errorBuilder: (context, error, stackTrace) => Icon(Icons.error),),
                            Flexible(child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(children: [
                                Expanded(child: Text(Utility.fileName(file: file),style: const TextStyle(overflow: TextOverflow.ellipsis,fontWeight: FontWeight.bold))),
                                const Icon(Icons.drag_indicator, color: Colors.grey),
                              ],),
                            ))
                          ],
                        )
                    );
                  },
                )),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: FilledButton(onPressed: _onConvertToPdf, child: const Text("Convert to pdf")),
                )
              ],
            ),
            if(state.isLoading(forr: HttpStates.IMAGE_TO_PDF)) Container(decoration: BoxDecoration(color: Colors.black54),child: Center(child: SpinKitThreeBounce(color: Colors.green,size: 45,),),)
          ],
        );
      },)
    );
  }

  void _reorder(oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final File file = widget.files.removeAt(oldIndex);
      widget.files.insert(newIndex, file);
    });
  }

  void _onConvertToPdf() async {
    bloc.add(ImageToPdfEvent(imageToPdf: ImageToPdf(out_file_name: outFileNameC.text.isEmpty ? "imageToPdf_file" : outFileNameC.text, files: await Future.wait(widget.files.map((file)=>MultipartFile.fromFile(file.path))))));
  }
}
