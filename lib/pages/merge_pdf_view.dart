import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/merge_pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/loading_overlay.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/utils/reorder_utils.dart';

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
  void dispose() {
    outFileNameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'merge')), elevation: 5),
      body: BlocConsumer<PdfBloc,PdfState>(
        listenWhen: (previous, current) => previous.httpStates[HttpStates.mergePdf]!=current.httpStates[HttpStates.mergePdf],
        buildWhen: (previous, current) => previous.httpStates[HttpStates.mergePdf]!=current.httpStates[HttpStates.mergePdf],
        listener: (context, state) {
          final httpState=state.httpStates[HttpStates.mergePdf];
          if(httpState?.done==true){
            AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: L10n.current.toolDone,color: Colors.green);
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
                    decoration: InputDecoration(labelText: L10n.of(context).outputFileName,border: const OutlineInputBorder()),
                    controller: outFileNameC),
                ),
                const SizedBox(height: 12,),
                Expanded(child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onReorderItem: _reorder,
                  scrollDirection: Axis.vertical,
                  itemCount: widget.files.length,
                  header: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: RichText(
                      text: TextSpan(
                        text: L10n.of(context).reorderFilesTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: L10n.of(context).longPressToDrag,
                            style: const TextStyle(fontSize: 12),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.surface),side: BorderSide(color: Theme.of(context).dividerColor)),
                        title: Text(
                          Utility.fileName(file: file),
                          style: const TextStyle(overflow: TextOverflow.ellipsis),
                        ),
                        leading: Icon(Icons.drag_indicator, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    );
                  },
                )),
                Container(width: double.infinity,padding: const EdgeInsets.all(16),child: FilledButton(onPressed: _startMerge, child: Text(ToolStrings.name(context, 'merge'))),)
              ],
            ),
            LoadingOverlay(httpState: state.httpStates[HttpStates.mergePdf], label: L10n.of(context).procWorking, onCancel: () => _cancelToken?.cancel('cancelled-by-user')),
          ],
        );
      },),
    );
  }

  void _reorder(oldIndex, newIndex) {
    setState(() => ReorderUtils.moveInPlace(widget.files, oldIndex, newIndex));
  }

  void _startMerge() async {
    _cancelToken = CancelToken();
    final bloc = BlocProvider.of<PdfBloc>(context);
    final files = await Future.wait(widget.files.map((file)=>MultipartFile.fromFile(file.path)));
    bloc.add(MergePdfEvent(mergePdf: MergePdf(outFileName: outFileNameC.text.isEmpty ? "merged_file" : outFileNameC.text, files: files), cancelToken: _cancelToken));
  }
}
