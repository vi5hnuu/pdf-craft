import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/unlock-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnProtectPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  UnProtectPdfView({super.key, required this.file, this.outFileName});

  @override
  State<UnProtectPdfView> createState() => _UnProtectPdfViewState();
}

class _UnProtectPdfViewState extends State<UnProtectPdfView> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  TextEditingController outputFileNameC=TextEditingController();
  String password="";
  String? _passwordHint;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    _loadPasswordHint();
  }

  Future<void> _loadPasswordHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hint = prefs.getString('pwd_hint_${widget.file.path.split('/').last}');
    if (hint != null && mounted) setState(() => _passwordHint = hint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('UnProtect Pdf'),
        elevation: 5,
      ),
      body:BlocConsumer<PdfBloc,PdfState>(
        buildWhen: (previous, current) => previous.httpStates[HttpStates.UNPROTECT_PDF]!=current.httpStates[HttpStates.UNPROTECT_PDF],
        listenWhen: (previous, current) => previous.httpStates[HttpStates.UNPROTECT_PDF]!=current.httpStates[HttpStates.UNPROTECT_PDF],
          listener: (context, state) {
            final httpState=state.httpStates[HttpStates.UNPROTECT_PDF];
            if(httpState?.done==true){
              AdsSingleton().dispatch(ShowInterstitialAd());
              NotificationService.showSnackbar(text: "UnProtected file successfully",color: Colors.green);
              if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
            }else if(httpState?.error!=null){
              NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
            }else if(httpState?.loading==true){
              NotificationService.showSnackbar(text: "Started file un-protection",color: Colors.lightBlue);
            }
          },
          builder: (context, state) {
           return Stack(
             children:[
               Padding(
                 padding: EdgeInsets.all(12),
                 child: Column(
                   mainAxisSize: MainAxisSize.max,
                   children:[
                     TextFormField(keyboardType: TextInputType.text,
                       decoration: InputDecoration(labelText: "Output File Name",border: OutlineInputBorder()),
                       controller: outputFileNameC,),
                     SizedBox(height: 12,),
                     if (_passwordHint != null) ...[
                       Card(
                         child: ListTile(
                           leading: Icon(Icons.lightbulb_outline, color: Colors.amber),
                           title: Text('Password Hint'),
                           subtitle: Text(_passwordHint!),
                         ),
                       ),
                       SizedBox(height: 12),
                     ],
                     TextFormField(keyboardType: TextInputType.text,
                         decoration: InputDecoration(labelText: "password",border: OutlineInputBorder()),
                         onChanged: (value) => setState(()=>password=value)),
                     SizedBox(height: 16,),
                     FilledButton(onPressed: password.isEmpty ? null : _onUnProtectPdf, child: Text("Remove password"))
                   ],
                 ),
               ),
               LoadingOverlay(httpState: state.httpStates[HttpStates.UNPROTECT_PDF]),
             ],
           );
          },),
    );
  }

  void _onUnProtectPdf() async{
    bloc.add(UnprotectPdfEvent(unlockPdf: UnProtectPdf(out_file_name: outputFileNameC.text.isEmpty ? "protected" : outputFileNameC.text, password: password, file: await MultipartFile.fromFile(widget.file.path))));
  }
}
