import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/extensions/string_etension.dart';
import 'package:pdf_craft/models/enums/direction.dart';
import 'package:pdf_craft/models/enums/quality.dart';
import 'package:pdf_craft/models/request/pdf_to_jpg.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/loading_overlay.dart';
import 'package:pdf_craft/widgets/page_range_selector.dart';

class PdfToJpgView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  const PdfToJpgView({super.key, required this.file, this.outFileName});

  @override
  State<PdfToJpgView> createState() => _PdfToJpgViewState();
}

class _PdfToJpgViewState extends State<PdfToJpgView> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  CancelToken? _cancelToken;

  /// 0-indexed pages to render. Empty means the whole document.
  final Set<int> _pages = <int>{};
  TextEditingController gapController=TextEditingController();
  int qualityDpi=Quality.LOW.dpi;
  bool isSingle=false;
  String? direction=Direction.VERTICAL.direction;
  final TextEditingController outFileNameC=TextEditingController();

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  void dispose() {
    gapController.dispose();
    outFileNameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ToolStrings.name(context, 'pdf-to-jpg')),
        elevation: 5,
      ),
      body: BlocConsumer<PdfBloc,PdfState>(
          buildWhen: (previous, current) => previous.httpStates[HttpStates.pdfToJpg]!=current.httpStates[HttpStates.pdfToJpg],
          listenWhen: (previous, current) => previous.httpStates[HttpStates.pdfToJpg]!=current.httpStates[HttpStates.pdfToJpg],
          listener: (context, state) {
        final httpState=state.httpStates[HttpStates.pdfToJpg];
        if(httpState?.done==true){
          AdsSingleton().dispatch(ShowInterstitialAd());
          final file=httpState?.extras?['savedFile'];
          NotificationService.showSnackbar(text: L10n.current.toolDone,color: Colors.green);
          if(file is File) _openFile(file);
        }else if(httpState?.error!=null){
          NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Flex(direction: Axis.vertical,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextFormField(keyboardType: TextInputType.text,
                      decoration: InputDecoration(labelText: L10n.of(context).outputFileName,border: const OutlineInputBorder()),
                      controller: outFileNameC),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(L10n.of(context).imageQuality, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Flexible(
                                child: DropdownButtonFormField(
                                    
                                    decoration: const InputDecoration(border: OutlineInputBorder()),initialValue: qualityDpi,
                                    items: Quality.values.map((quality)=>DropdownMenuItem(value: quality.dpi,child: Text(quality.name.capitalize()),)).toList(), onChanged: (value){
                                  if(value!=null) setState(() =>qualityDpi=value);
                                }),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),//isSingle
                          if(isSingle) Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(L10n.of(context).imageGap, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Flexible(
                                child: TextFormField(keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                    controller: gapController,
                                    validator: (value){
                                      final val=int.tryParse(gapController.value.text);
                                      return val!=null && val>0 ? null : L10n.of(context).invalidGap;
                                    }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),//isSingle
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              children: [
                                Text(L10n.of(context).generateSingleImage, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 16,),
                                Switch(value: isSingle, onChanged: (value)=>setState(() =>isSingle=value))
                              ],
                            ),
                          ),
                          AnimatedOpacity(opacity: isSingle ? 1 : 0, duration: const Duration(milliseconds: 300),child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(L10n.of(context).joinImages, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16,),
                              Flexible(child: DropdownButtonFormField(
                                  
                                  decoration: const InputDecoration(border: OutlineInputBorder()),initialValue: direction,items: Direction.values.map((direction)=>DropdownMenuItem(value: direction.direction,child: Text(direction.name.capitalize(),),)).toList(), onChanged: (value){
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    // Rendering is the costliest thing this tool does, so converting 200 pages
                    // to get one was expensive in both time and credits.
                    child: PageRangeSelector(
                      file: widget.file,
                      selected: _pages,
                      onChanged: (pages) => setState(() {
                        _pages
                          ..clear()
                          ..addAll(pages);
                      }),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    child: FilledButton(onPressed: (isSingle && direction==null) ? null : _onPdfToJpf, child: Text(ToolStrings.name(context, 'pdf-to-jpg'))),
                  )
                ],),
            ),
            LoadingOverlay(httpState: state.httpStates[HttpStates.pdfToJpg], label: L10n.of(context).procWorking, onCancel: () => _cancelToken?.cancel('cancelled-by-user')),
          ],
        );
      },),
    );
  }

  void _onPdfToJpf() async {
    _cancelToken = CancelToken();
    final file = await MultipartFile.fromFile(widget.file.path);
    bloc.add(PdfToJpgEvent(pdfToJpg: PdfToJpg(file: file, meta: PdfToJpgMeta(outFileName: outFileNameC.text.isEmpty ? "pdfToJpg_file" : outFileNameC.text, quality: Quality.fromDpi(qualityDpi), single: isSingle, direction: isSingle ?  Direction.fromJson(direction!) : null, imageGap: isSingle ? int.tryParse(gapController.value.text) ?? 0 : null, pages: _pages.toList()..sort())), cancelToken: _cancelToken));
  }

  void _openFile(File file) {
    OpenFile.open(file.path,type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(file)] ?? '*/*');
  }
}
