import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/merge-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class MergePdfView extends StatefulWidget {
  final List<File> files;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  const MergePdfView({super.key, required this.files});

  @override
  State<MergePdfView> createState() => _MergePdfViewState();
}

class _MergePdfViewState extends State<MergePdfView> {
  final TextEditingController outFileNameC=TextEditingController();
  int? draggingItemIndex;
  CancelToken? _cancelToken;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDF'), elevation: 5),
      body: BlocConsumer<PdfBloc,PdfState>(
        listenWhen: (previous, current) => previous.httpStates[HttpStates.MERGE_PDF]!=current.httpStates[HttpStates.MERGE_PDF],
        buildWhen: (previous, current) => previous.httpStates[HttpStates.MERGE_PDF]!=current.httpStates[HttpStates.MERGE_PDF],
        listener: (context, state) {
          final httpState=state.httpStates[HttpStates.MERGE_PDF];
          if(httpState?.done==true){
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: "Merge Successfull",color: Colors.green);
            if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
          }else if(httpState?.error!=null){
            NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
          }
        },
        builder: (context, state) {
        return Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(keyboardType: TextInputType.text,
                    decoration: InputDecoration(labelText: "Output File Name",border: OutlineInputBorder()),
                    controller: outFileNameC),
                ),
                SizedBox(height: 12,),
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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: '( long press to drag )',
                            style: TextStyle(fontSize: 12),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6),side: BorderSide(color: Theme.of(context).dividerColor)),
                        title: Text(
                          Utility.fileName(file: file),
                          style: const TextStyle(overflow: TextOverflow.ellipsis),
                        ),
                        leading: Icon(Icons.drag_indicator, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    );
                  },
                )),
                Container(width: double.infinity,padding: const EdgeInsets.all(16),child: FilledButton(onPressed: _startMerge, child: const Text("Merge PDFs")),)
              ],
            ),
            LoadingOverlay(httpState: state.httpStates[HttpStates.MERGE_PDF], label: 'Merging your PDFs', onCancel: () => _cancelToken?.cancel('cancelled-by-user')),
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

  void _startMerge() async {
    _cancelToken = CancelToken();
    final bloc = BlocProvider.of<PdfBloc>(context);
    final files = await Future.wait(widget.files.map((file)=>MultipartFile.fromFile(file.path)));
    bloc.add(MergePdfEvent(mergePdf: MergePdf(out_file_name: outFileNameC.text.isEmpty ? "merged_file" : outFileNameC.text, files: files), cancelToken: _cancelToken));
  }
}
