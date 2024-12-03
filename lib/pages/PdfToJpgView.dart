import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/direction.dart';
import 'package:pdf_craft/models/enums/quality.dart';
import 'package:pdf_craft/models/request/pdf-to-jpg.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';

class PdfToJpgView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  PdfToJpgView({super.key, required this.file, this.outFileName}) {}

  @override
  State<PdfToJpgView> createState() => _PdfToJpgViewState();
}

class _PdfToJpgViewState extends State<PdfToJpgView> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  TextEditingController gapController=TextEditingController();
  int qualityDpi=Quality.LOW.dpi;
  bool isSingle=false;
  String? direction;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Pdf To Jpg'),
        elevation: 5,
      ),
      body: BlocListener<PdfBloc,PdfState>(listener: (context, state) {
        final httpState=state.httpStates[HttpStates.REORDER_PDF];
        if(httpState?.done==true){
          NotificationService.showSnackbar(text: "Page to Jpeg Successfull",color: Colors.green);
          if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
        }else if(httpState?.error!=null){
          NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
        }else if(httpState?.loading==true){
          NotificationService.showSnackbar(text: "Started converting to jpg",color: Colors.lightBlue);
        }
      },child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if(isSingle) DropdownButton(value: direction,items: Direction.values.map((direction)=>DropdownMenuItem(child: Text(direction.name.capitalize()),value: direction.direction,)).toList(), onChanged: (value){
            if(value!=null) setState(()=>direction=value);
          }),
          DropdownButton(value: qualityDpi,items: Quality.values.map((quality)=>DropdownMenuItem(child: Text(quality.name.capitalize()),value: quality.dpi,)).toList(), onChanged: (value){
            if(value!=null) setState(() =>qualityDpi=value);
          }),
          Switch(value: true, onChanged: (value)=>setState(() =>isSingle=value)),//isSingle
          if(isSingle) TextFormField(keyboardType: TextInputType.number,
              controller: gapController,
              validator: (value){
                final val=int.tryParse(gapController.value.text);
                return val!=null && val>0 ? null : "Invalid gap";
              }),//gap
          FilledButton(onPressed: _onPdfToJpf, child: const Text("Convert to Jpg"))
        ],
      )),
    );
  }

  void _onPdfToJpf() async {
    bloc.add(PdfToJpgEvent(pdfToJpg: PdfToJpg(file: await MultipartFile.fromFile(widget.file.path), out_file_name: "out_file_name", quality: Quality.fromDpi(qualityDpi), single: isSingle, direction: isSingle ?  Direction.fromJson(direction!) : null, imageGap: isSingle ? int.tryParse(gapController.value.text) ?? 0 : null)));
  }
}
