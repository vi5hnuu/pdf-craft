import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/unlock-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

class UnProtectPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  UnProtectPdfView({super.key, required this.file, this.outFileName});

  @override
  State<UnProtectPdfView> createState() => _UnProtectPdfViewState();
}

class _UnProtectPdfViewState extends State<UnProtectPdfView> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  TextEditingController outputFileNameC=TextEditingController();
  String password="";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('UnProtect Pdf'),
        elevation: 5,
      ),
      body:BlocListener<PdfBloc,PdfState>(listenWhen: (previous, current) => previous.httpStates[HttpStates.UNPROTECT_PDF]!=current.httpStates[HttpStates.UNPROTECT_PDF],
          listener: (context, state) {
            final httpState=state.httpStates[HttpStates.UNPROTECT_PDF];
            if(httpState?.done==true){
              NotificationService.showSnackbar(text: "UnProtected file successfully",color: Colors.green);
              if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
            }else if(httpState?.error!=null){
              NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
            }else if(httpState?.loading==true){
              NotificationService.showSnackbar(text: "Started file un-protection",color: Colors.lightBlue);
            }
          },child: Padding(
          padding: EdgeInsets.all(12),
            child: Column(
            mainAxisSize: MainAxisSize.max,
            children:[
              TextFormField(keyboardType: TextInputType.text,
                  decoration: InputDecoration(labelText: "Output File Name",border: OutlineInputBorder()),
                  controller: outputFileNameC,),
              SizedBox(height: 12,),
              TextFormField(keyboardType: TextInputType.text,
                          decoration: InputDecoration(labelText: "password",border: OutlineInputBorder()),
                          onChanged: (value) => setState(()=>password=value)),
              SizedBox(height: 16,),
              FilledButton(onPressed: password.isEmpty ? null : _onUnProtectPdf, child: Text("Remove password"))
            ],
                    ),
          ),),
    );
  }

  void _onUnProtectPdf() async{
    bloc.add(UnprotectPdfEvent(unlockPdf: UnProtectPdf(out_file_name: outputFileNameC.text.isEmpty ? "protected" : outputFileNameC.text, password: password, file: await MultipartFile.fromFile(widget.file.path))));
  }
}
