import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/direction.dart';
import 'package:pdf_craft/models/enums/quality.dart';
import 'package:pdf_craft/models/request/pdf-to-jpg.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Pdf To Jpg'),
        elevation: 5,
      ),
      body: BlocListener<PdfBloc,PdfState>(
          listenWhen: (previous, current) => previous.httpStates[HttpStates.PDF_TO_JPG]!=current.httpStates[HttpStates.PDF_TO_JPG],
          listener: (context, state) {
        final httpState=state.httpStates[HttpStates.PDF_TO_JPG];
        if(httpState?.done==true){
          final file=httpState?.extras?['savedFile'];
          NotificationService.showSnackbar(text: "Page to Jpeg Successfull",color: Colors.green);
          if(file is File) _openFile(file);
        }else if(httpState?.error!=null){
          NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
        }else if(httpState?.loading==true){
          NotificationService.showSnackbar(text: "Started converting to jpg",color: Colors.lightBlue);
        }
      },child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Flex(direction: Axis.vertical,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  DropdownButtonFormField(
                      dropdownColor: Colors.black,
                      decoration: InputDecoration(border: OutlineInputBorder()),value: qualityDpi,
                      items: Quality.values.map((quality)=>DropdownMenuItem(child: Text(quality.name.capitalize()),value: quality.dpi,)).toList(), onChanged: (value){
                    if(value!=null) setState(() =>qualityDpi=value);
                  }),
                  SizedBox(height: 16),//isSingle
                  SizedBox(height: 16),//isSingle
                  if(isSingle) Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: TextFormField(keyboardType: TextInputType.number,
                        decoration: InputDecoration(border: OutlineInputBorder()),
                        controller: gapController,
                        validator: (value){
                          final val=int.tryParse(gapController.value.text);
                          return val!=null && val>0 ? null : "Invalid gap";
                        }),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Text("Generate Single Image ",style: TextStyle(fontSize: 20),),
                        SizedBox(width: 16,),
                        Switch(value: isSingle, onChanged: (value)=>setState(() =>isSingle=value))
                      ],
                    ),
                  ),
                  AnimatedOpacity(opacity: isSingle ? 1 : 0, duration: Duration(milliseconds: 300),child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Join Images ",style: TextStyle(fontSize: 20),),
                      SizedBox(width: 16,),
                      Flexible(child: DropdownButtonFormField(
                          dropdownColor: Colors.black,
                          decoration: InputDecoration(border: OutlineInputBorder()),value: direction,items: Direction.values.map((direction)=>DropdownMenuItem(child: Text(direction.name.capitalize(),),value: direction.direction,)).toList(), onChanged: (value){
                        if(value!=null) setState(()=>direction=value);
                      }))
                    ],
                  ),),
                  if(!isSingle)Image.asset("assets/tools/image-group-zip.png",fit: BoxFit.fitWidth,),
                  if(isSingle && direction==Direction.HORIZONTAL.direction)Image.asset("assets/tools/image-horizontal-list.png",fit: BoxFit.fitWidth,),
                  if(isSingle && direction==Direction.VERTICAL.direction) Image.asset("assets/tools/image-vertical-list.png",fit: BoxFit.fitWidth,),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            width: double.infinity,
            child: FilledButton(onPressed: (isSingle && direction==null) || (!isSingle &&  gapController.value.text.isEmpty) ? null :  _onPdfToJpf, child: const Text("Convert to Jpg")),
          )
        ],),
      )),
    );
  }

  void _onPdfToJpf() async {
    bloc.add(PdfToJpgEvent(pdfToJpg: PdfToJpg(file: await MultipartFile.fromFile(widget.file.path), meta: PdfToJpgMeta(out_file_name: "out_file_name", quality: Quality.fromDpi(qualityDpi), single: isSingle, direction: isSingle ?  Direction.fromJson(direction!) : null, imageGap: isSingle ? int.tryParse(gapController.value.text) ?? 0 : null))));
  }

  void _openFile(File file) {
    OpenFile.open(file.path,type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(file)] ?? '*/*');
  }
}
