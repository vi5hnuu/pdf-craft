import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/routes.dart';
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

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Image to Pdf'),
        elevation: 5,
      ),
      body: BlocListener<PdfBloc,PdfState>(listener: (context, state) {
        final httpState=state.httpStates[HttpStates.IMAGE_TO_PDF];
        if(httpState?.done==true){
          NotificationService.showSnackbar(text: "Image to pdf successfull",color: Colors.green);
          if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
        }else if(httpState?.error!=null){
          NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
        }else if(httpState?.loading==true){
          NotificationService.showSnackbar(text: "Started converting image/s to pdf",color: Colors.lightBlue);
        }
      },child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
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
            itemBuilder: (context, index) {
              final file = widget.files[index];
              return Padding(
                key: ValueKey(file.path),
                padding: const EdgeInsets.symmetric(horizontal: 8.0,vertical: 2),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6),side: BorderSide(color: Colors.grey)),
                  title: Text(
                    Utility.fileName(file: file),
                    style: TextStyle(overflow: TextOverflow.ellipsis, color: Colors.black),
                  ),
                  leading: Icon(Icons.drag_indicator, color: Colors.grey),
                  tileColor: Colors.white,
                ),
              );
            },
          )),
          FilledButton(onPressed: _onConvertToPdf, child: const Text("Convert to pdf"))
        ],
      ))
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
    bloc.add(ImageToPdfEvent(imageToPdf: ImageToPdf(out_file_name: "out_file_name", files: await Future.wait(widget.files.map((file)=>MultipartFile.fromFile(file.path))))));
  }
}
