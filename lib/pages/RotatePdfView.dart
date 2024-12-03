import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

class RotatePdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  RotatePdfView({super.key, required this.file, this.outFileName}) {}

  @override
  State<RotatePdfView> createState() => _RotatePdfViewState();
}

class _RotatePdfViewState extends State<RotatePdfView> {
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
        title: Text('Rotate pdf pages'),
        elevation: 5,
      ),
      body: BlocListener<PdfBloc,PdfState>(
          listenWhen: (previous, current) => previous.httpStates[HttpStates.ROTATE_PDF]!=current.httpStates[HttpStates.ROTATE_PDF],
          listener: (context, state) {
            final httpState=state.httpStates[HttpStates.ROTATE_PDF];
            if(httpState?.done==true){
              NotificationService.showSnackbar(text: "Page rotation successfull",color: Colors.green);
              if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
            }else if(httpState?.error!=null){
              NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
            }else if(httpState?.loading==true){
              NotificationService.showSnackbar(text: "Started rotating pdf pages",color: Colors.lightBlue);
            }
          },child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [],
      )),
    );
  }

  void _onRotatePdfPages() async {
    // bloc.add(RotatePdfEvent(rotatePdf: RotatePdf(out_file_name: "out_file_name", file_angle: file_angle, page_angles: page_angles, file: file, maintain_ratio: maintain_ratio)))
  }
}
