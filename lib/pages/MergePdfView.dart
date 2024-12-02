import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/models/request/merge-pdf.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';

class MergePdfView extends StatefulWidget {
  final List<File> files;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  const MergePdfView({super.key, required this.files, this.outFileName});

  @override
  State<MergePdfView> createState() => _MergePdfViewState();
}

class _MergePdfViewState extends State<MergePdfView> {
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
        title: const Text('Merge Pdf'),
        elevation: 5,
      ),
      body: BlocConsumer<PdfBloc,PdfState>(
        listenWhen: (previous, current) => previous.httpStates[HttpStates.MERGE_PDF]!=current.httpStates[HttpStates.MERGE_PDF],
        buildWhen: (previous, current) => previous.httpStates[HttpStates.MERGE_PDF]!=current.httpStates[HttpStates.MERGE_PDF],
        listener: (context, state) {
          if(state.isDone(forr: HttpStates.MERGE_PDF)){
            NotificationService.showSnackbar(text: "Merge Successfull",color: Colors.green);
          }else if(state.isError(forr: HttpStates.MERGE_PDF)){
            NotificationService.showSnackbar(text: "Merge failed",color: Colors.red);
          }else{
            NotificationService.showSnackbar(text: "Stated merging",color: Colors.lightBlue);
          }
        },
        builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              onReorder: _reorder,
              scrollDirection: Axis.vertical,
              itemCount: widget.files.length,
              header: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6),side: const BorderSide(color: Colors.grey)),
                    title: Text(
                      Utility.fileName(file: file),
                      style: const TextStyle(overflow: TextOverflow.ellipsis, color: Colors.black),
                    ),
                    leading: const Icon(Icons.drag_indicator, color: Colors.grey),
                    tileColor: Colors.white,
                  ),
                );
              },
            )),
            Container(decoration: const BoxDecoration(color: Colors.white),width: double.infinity,padding: const EdgeInsets.all(16),child: FilledButton(onPressed: _startMerge, child: const Text("Merge Pdf's")),)
          ],
        );
      },),
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

  void _startMerge() {
    BlocProvider.of<PdfBloc>(context).add(MergePdfEvent(mergePdf: MergePdf(out_file_name: "out_file_name", files: widget.files)));
  }
}
