import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/enums/split-type.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/pages/split-pdf-tool/SplitConfig.dart';
import 'package:pdf_craft/pages/split-pdf-tool/SplitRange.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';

class SplitPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  SplitPdfView({super.key, required this.file,this.outFileName});

  @override
  State<SplitPdfView> createState() => _SplitPdfViewState();
}

class _SplitPdfViewState extends State<SplitPdfView> {
  late GoRouter router=GoRouter.of(context);
  late PdfBloc bloc=BlocProvider.of(context);
  SplitType? type=SplitType.EXTRACT_ALL_PAGES;
  int? fixed;
  List<RangeModel> ranges=[];
  final TextEditingController outFileNameC=TextEditingController();

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final router=GoRouter.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Split Pdf'),
        elevation: 5,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if(type!=null) setState(()=>type=null);
          else router.pop();
        },
        child: BlocConsumer<PdfBloc,PdfState>(
          buildWhen: (previous, current) => previous.httpStates[HttpStates.SPLIT_PDF]!=current.httpStates[HttpStates.SPLIT_PDF],
          listenWhen: (previous, current) => previous.httpStates[HttpStates.SPLIT_PDF]!=current.httpStates[HttpStates.SPLIT_PDF],
            listener: (context, state) {
              final httpState=state.httpStates[HttpStates.SPLIT_PDF];
              if(httpState?.done==true){
                final file=httpState?.extras?['savedFile'];
                NotificationService.showSnackbar(text: "Splitting Pdf Successfull",color: Colors.green);
                if(file is File) OpenFile.open(file.path,type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(file)]);
              }else if(httpState?.error!=null){
                NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
              }else if(httpState?.loading==true){
                NotificationService.showSnackbar(text: "Started Splitting",color: Colors.lightBlue);
              }
            },
          builder: (context, state) {
            return Stack(
              children: [
                Flex(direction: Axis.vertical,children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(keyboardType: TextInputType.text,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(labelText: "Output File Name" ,border: OutlineInputBorder()),
                        controller: outFileNameC),
                  ),
                  if(type==null || type==SplitType.EXTRACT_ALL_PAGES) SplitConfig(type: type,onSplitSelect: (splitType) => setState(()=>type=splitType))
                  else SplitPdfRange(file: widget.file, type: type!,onRangeChange:(rgs)=>setState(()=>ranges=rgs)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: FilledButton(onPressed: type==null || (type!=SplitType.EXTRACT_ALL_PAGES && ranges.isEmpty)  ? null : _onExtractAllPages, child: const Text("Split Pdf Pages")),
                  )
                ],),
                if(state.isLoading(forr: HttpStates.SPLIT_PDF)) Container(decoration: BoxDecoration(color: Colors.black54),child: Center(child: SpinKitThreeBounce(color: Colors.green,size: 45,),),)
              ],
            );
          },
            ),
      ));
  }

  _onExtractAllPages() async{
    bloc.add(SplitPdfEvent(splitPdf: SplitPdf(out_file_name: outFileNameC.text.isEmpty ? "splitted_file" : outFileNameC.text, type: type!, fixed: type==SplitType.FIXED_RANGE ? ranges.first.from : null, ranges: [SplitType.FIXED_RANGE,SplitType.EXTRACT_ALL_PAGES].contains(type) ? null : ranges, file: await MultipartFile.fromFile(widget.file.path))));
  }
}

