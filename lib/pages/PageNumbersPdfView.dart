import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/color-info.dart';
import 'package:pdf_craft/models/enums/font.dart';
import 'package:pdf_craft/models/enums/page-no-type.dart';
import 'package:pdf_craft/models/enums/position-info.dart';
import 'package:pdf_craft/models/padding-info.dart';
import 'package:pdf_craft/models/request/page-numbers.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/PdfPageThumbnail.dart';
import 'package:pdfx/pdfx.dart';

class PageNumberPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  PageNumberPdfView({super.key, required this.file, this.outFileName});

  @override
  State<PageNumberPdfView> createState() => _PageNumberPdfViewState();
}

class _PageNumberPdfViewState extends State<PageNumberPdfView> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  PageNoType page_no_type=PageNoType.PAGE_X_OF_Y;
  TextEditingController fontSizeC=TextEditingController(text: "20");
  ColorInfo fill_color=ColorInfo(r: 255, g: 0, b: 0, a: 255);
  PositionInfo vertical_position=PositionInfo.START;
  PositionInfo horizontal_position=PositionInfo.CENTER;
  PaddingInfo padding=PaddingInfo(top: 10, left: 0, bottom: 0, right: 0);
  int from_page=0;
  int? to_page;
  FontName font_name=FontName.TIMES_BOLD;
  final TextEditingController outFileNameC=TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Pdf Page Number'),
        elevation: 5,
      ),
      body: BlocConsumer<PdfBloc,PdfState>(
          buildWhen: (previous, current) => previous.httpStates[HttpStates.PAGE_NUMBERS]!=current.httpStates[HttpStates.PAGE_NUMBERS],
          listenWhen: (previous, current) => previous.httpStates[HttpStates.PAGE_NUMBERS]!=current.httpStates[HttpStates.PAGE_NUMBERS],
          listener: (context, state) {
            final httpState=state.httpStates[HttpStates.PAGE_NUMBERS];
            if(httpState?.done==true){
              NotificationService.showSnackbar(text: "Page Number Write Successfull",color: Colors.green);
              if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
            }else if(httpState?.error!=null){
              NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
            }else if(httpState?.loading==true){
              NotificationService.showSnackbar(text: "Page Number Write Started",color: Colors.lightBlue);
            }
          },
      builder: (context, state) {
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0).copyWith(bottom: 12),
                            child: TextFormField(keyboardType: TextInputType.text,
                              decoration: InputDecoration(labelText: "Output File Name",border: OutlineInputBorder()),
                              controller: outFileNameC,style: TextStyle(color: Colors.white),),
                          ),
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Page View Type",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Flexible(
                                  child: DropdownButtonFormField(
                                      dropdownColor: Colors.black,
                                      decoration: InputDecoration(border: OutlineInputBorder()),value: page_no_type,
                                      items: PageNoType.values.map((pageNoType)=>DropdownMenuItem(value: pageNoType,child: Text(pageNoType.name.split('_').join(' ').capitalize()),)).toList(),
                                      onChanged: (value){
                                        if(value!=null) setState(() =>page_no_type=value);
                                      }),
                                ),
                              ]),
                          SizedBox(height: 16),
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Font Size",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Flexible(
                                  child: TextFormField(keyboardType: TextInputType.number,
                                      decoration: InputDecoration(border: OutlineInputBorder()),
                                      controller: fontSizeC,
                                      validator: (value){
                                        final val=int.tryParse(fontSizeC.value.text);
                                        return val!=null && (val<5) ? null : "Invalid font-size";
                                      }),
                                ),
                              ]),
                          SizedBox(height: 16),
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Vertical Position",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Flexible(
                                  child: DropdownButtonFormField(
                                      dropdownColor: Colors.black,
                                      decoration: InputDecoration(border: OutlineInputBorder()),value: vertical_position,
                                      items: PositionInfo.values.map((positionInfo)=>DropdownMenuItem(child: Text(positionInfo.name.capitalize()),value: positionInfo)).toList(), onChanged: (value){
                                    if(value!=null) setState(() =>vertical_position=value as PositionInfo);
                                  }),
                                ),
                              ]),
                          SizedBox(height: 16),
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Horizontal Position",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Flexible(
                                  child: DropdownButtonFormField(
                                      dropdownColor: Colors.black,
                                      decoration: InputDecoration(border: OutlineInputBorder()),value: horizontal_position,
                                      items: PositionInfo.values.map((positionInfo)=>DropdownMenuItem(child: Text(positionInfo.name.capitalize()),value: positionInfo)).toList(), onChanged: (value){
                                    if(value!=null) setState(() =>horizontal_position=value as PositionInfo);
                                  }),
                                ),
                              ]),
                          SizedBox(height: 16),
                          Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Text("Padding",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Expanded(
                                    child: Flex(
                                      direction: Axis.horizontal,
                                      children: [
                                        Flexible(
                                          child: TextFormField(keyboardType: TextInputType.number,
                                              decoration: InputDecoration(labelText: "Top",border: OutlineInputBorder()),
                                              initialValue: padding.top.toString(),
                                              onChanged: (value) => setState(()=>padding.top=double.parse(value))),
                                        ),
                                        SizedBox(width: 8,),
                                        Flexible(
                                          child: TextFormField(keyboardType: TextInputType.number,
                                              decoration: InputDecoration(labelText: "Right",border: OutlineInputBorder()),
                                              initialValue: padding.right.toString(),
                                              onChanged: (value) => setState(()=>padding.right=double.parse(value))),
                                        ),
                                        SizedBox(width: 8,),
                                        Flexible(
                                          child: TextFormField(keyboardType: TextInputType.number,
                                              decoration: InputDecoration(labelText: "Bottom",border: OutlineInputBorder()),
                                              initialValue: padding.bottom.toString(),
                                              onChanged: (value) => setState(()=>padding.bottom=double.parse(value))),
                                        ),
                                        SizedBox(width: 8,),
                                        Flexible(
                                          child: TextFormField(keyboardType: TextInputType.number,
                                              decoration: InputDecoration(labelText: "Left",border: OutlineInputBorder()),
                                              initialValue: padding.left.toString(),
                                              onChanged: (value) => setState(()=>padding.left=double.parse(value))),
                                        ),

                                      ],)
                                ),
                              ]),
                          SizedBox(height: 16),
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("From Page",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Flexible(
                                  child: TextFormField(keyboardType: TextInputType.number,
                                      decoration: InputDecoration(border: OutlineInputBorder()),
                                      initialValue: from_page.toString(),
                                      onChanged: (value) => setState(()=>from_page=int.parse(value)),
                                      validator: (value){
                                        final val=int.tryParse(fontSizeC.value.text);
                                        return val!=null && val>=0 ? null : "Invalid from page";
                                      }),
                                ),
                                SizedBox(width: 16),
                                Text("To Page",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Flexible(
                                  child: TextFormField(keyboardType: TextInputType.number,
                                      decoration: InputDecoration(border: OutlineInputBorder()),
                                      onChanged: (value) => setState(()=>from_page=int.parse(value)),
                                      validator: (value){
                                        final val=int.tryParse(fontSizeC.value.text);
                                        return val!=null && val>=0 ? null : "Invalid to page";
                                      }),
                                ),
                              ]),
                          SizedBox(height: 16),
                          Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Font Name",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                                SizedBox(width: 12),
                                Flexible(
                                  child: DropdownButtonFormField(
                                      dropdownColor: Colors.black,
                                      menuMaxHeight: 300,
                                      decoration: InputDecoration(border: OutlineInputBorder()),value: font_name,
                                      items: FontName.values.map((fontName)=>DropdownMenuItem(child: Text(fontName.name.split('_').join(' ').capitalize()),value: fontName)).toList(), onChanged: (value){
                                    if(value!=null) setState(() =>font_name=value as FontName);
                                  }),
                                ),
                              ]),
                          SizedBox(height: 16),
                          ColorPicker(
                            colorPickerWidth: 100,
                            pickerColor: Color.fromARGB(fill_color.a ?? 1, fill_color.r, fill_color.g, fill_color.b),
                            onColorChanged: (color) {
                              setState(()=>fill_color=ColorInfo(r: color.red, g: color.green, b: color.blue, a: color.alpha));
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: MediaQuery.of(context).size.width*1.26,
                                  decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(12)),
                                ),
                                Container(
                                  width: double.infinity,
                                  height: MediaQuery.of(context).size.width*1.26,
                                  child: Align(
                                    alignment: _getPageAlignment(horizontal_position, vertical_position),
                                    child: Padding(
                                      padding: EdgeInsets.only(left: padding.left,top: padding.top,right: padding.right,bottom: padding.bottom),
                                      child: Text(page_no_type.type.split("_").join(" "),style: TextStyle(fontSize: double.parse(fontSizeC.text),color: Color.fromARGB(fill_color.a ?? 1, fill_color.r, fill_color.g, fill_color.b)),),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Container(
                      padding: EdgeInsets.all(12),
                      width: double.infinity,
                      child: FilledButton(onPressed: _onPageNumbersPages, child: const Text("Confirm changes")))
                ],
              ),
            ),
            if(state.isLoading(forr: HttpStates.PAGE_NUMBERS)) Expanded(child: Container(decoration: BoxDecoration(color: Colors.black54),child: Center(child: SpinKitThreeBounce(color: Colors.green,size: 45,),),))
          ],
        );
      },),
    );
  }

  void _onPageNumbersPages() async {
    bloc.add(PageNumbersEvent(pageNumber: PageNumbers(out_file_name: outFileNameC.text.isEmpty ? "pageNumbers_file" : outFileNameC.text, page_no_type: page_no_type, size: int.parse(fontSizeC.text), fill_color: fill_color, vertical_position: vertical_position, horizontal_position: horizontal_position, padding: padding, from_page: from_page, to_page: to_page, file: await MultipartFile.fromFile(widget.file.path), font_name: font_name)));
  }

  Alignment _getPageAlignment(PositionInfo horizontal_position, PositionInfo vertical_position) {
    if(horizontal_position==PositionInfo.START && vertical_position==PositionInfo.START) return Alignment.topLeft;
    else if(horizontal_position==PositionInfo.CENTER && vertical_position==PositionInfo.START) return Alignment.topCenter;
    else if(horizontal_position==PositionInfo.END && vertical_position==PositionInfo.START) return Alignment.topRight;
    else if(horizontal_position==PositionInfo.START && vertical_position==PositionInfo.CENTER) return Alignment.centerLeft;
    else if(horizontal_position==PositionInfo.CENTER && vertical_position==PositionInfo.CENTER) return Alignment.center;
    else if(horizontal_position==PositionInfo.END && vertical_position==PositionInfo.CENTER) return Alignment.centerRight;
    else if(horizontal_position==PositionInfo.START && vertical_position==PositionInfo.END) return Alignment.bottomLeft;
    else if(horizontal_position==PositionInfo.CENTER && vertical_position==PositionInfo.END) return Alignment.bottomCenter;
    else return Alignment.bottomRight;
  }
}
