import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/direction.dart';
import 'package:pdf_craft/models/enums/quality.dart';
import 'package:pdf_craft/utils/utility.dart';

class PdfToJpgView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  PdfToJpgView({super.key, required this.file, this.outFileName}) {
  }

  @override
  State<PdfToJpgView> createState() => _PdfToJpgViewState();
}

class _PdfToJpgViewState extends State<PdfToJpgView> {
  TextEditingController gapController=TextEditingController();
  bool isSingle=false;

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
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if(isSingle) DropdownButton(items: Direction.values.map((direction)=>DropdownMenuItem(child: Text(direction.name.capitalize()),value: direction.direction,)).toList(), onChanged: (value){},),
          DropdownButton(items: Quality.values.map((quality)=>DropdownMenuItem(child: Text(quality.name.capitalize()),value: quality.dpi,)).toList(), onChanged: (value){},),
          Switch(value: true, onChanged: (value)=>setState(() =>isSingle=value)),//isSingle
          if(isSingle) TextFormField(keyboardType: TextInputType.number,
            controller: gapController,
            validator: (value){
            final val=int.tryParse(gapController.value.text);
              return val!=null && val>0 ? null : "Invalid gap";
            }),//gap
          FilledButton(onPressed: (){}, child: const Text("Convert to Jpg"))
        ],
      ),
    );
  }
}
