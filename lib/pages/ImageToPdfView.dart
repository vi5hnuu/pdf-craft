import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/utils/utility.dart';

class ImageToPdfView extends StatefulWidget {
  final List<File> files;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  ImageToPdfView({super.key, required this.files, this.outFileName}) {
    files.addAll(List.generate(
      50,
          (index) => File("this is a big name for file${index + 1}.pdf"),
    ));
  }

  @override
  State<ImageToPdfView> createState() => _ImageToPdfViewState();
}

class _ImageToPdfViewState extends State<ImageToPdfView> {
  int? draggingItemIndex;

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
      body: Column(
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
            onReorderStart: (index)=>setState(()=>draggingItemIndex=index),
            onReorderEnd: (index)=>setState(()=>draggingItemIndex=null),
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
          FilledButton(onPressed: (){}, child: const Text("Convert to pdf"))
        ],
      ),
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
}
