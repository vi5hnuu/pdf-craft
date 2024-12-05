import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/models/request/split-pdf.dart';
import 'package:pdf_craft/models/thumbnail.dart';

class SplitItem extends StatelessWidget {
  final pageWidth=150.0;
  final RangeModel range;
  final Thumbnail startThumbnail;
  final Thumbnail? endThumbnail;
  final VoidCallback? onDelete;

  const SplitItem({
    super.key,
    required this.range,
    required this.startThumbnail,
    required this.endThumbnail,
    this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: pageWidth*1.4,
            width: pageWidth,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey),borderRadius: BorderRadius.circular(8)),
            child: (startThumbnail.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (startThumbnail.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(startThumbnail.image!.bytes,fit: BoxFit.fitWidth,)),
          ),
          if(endThumbnail!=null) Column(
            children: [
              Text("${range.from+1}-${range.to+1}"),
              SizedBox(width: 50,child: Container(height: 2,decoration: BoxDecoration(color: Colors.white),),)
            ],
          ),
          if(endThumbnail!=null) Container(
            height: pageWidth*1.4,
            width: pageWidth,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey),borderRadius: BorderRadius.circular(8)),
            child: (endThumbnail!.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (endThumbnail!.error!=null ? const Center(child: Icon(Icons.error),) : Image.memory(endThumbnail!.image!.bytes,fit: BoxFit.fitWidth,)),
          )
        ],
      ),
      if(onDelete!=null) Positioned(top: 0,right: 30,child: IconButton(onPressed: onDelete, icon: Icon(Icons.delete,color: Colors.red,),))
    ],);
  }
}
