import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/user-access-permission.dart';
import 'package:pdf_craft/models/request/protect-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

class ProtectPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  ProtectPdfView({super.key, required this.file, this.outFileName}) {
  }

  @override
  State<ProtectPdfView> createState() => _ProtectPdfViewState();
}

class _ProtectPdfViewState extends State<ProtectPdfView> {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  final TextEditingController outFileNameC=TextEditingController();
  String ownerPassword="";
  String userPassword="";
  final List<UserAccessPermission> userPermissions=[];

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Protect Pdf'),
        elevation: 5,
      ),
      body: BlocConsumer<PdfBloc,PdfState>(
        buildWhen: (previous, current) => previous.httpStates[HttpStates.PROTECT_PDF]!=current.httpStates[HttpStates.PROTECT_PDF],
        listenWhen: (previous, current) => previous.httpStates[HttpStates.PROTECT_PDF]!=current.httpStates[HttpStates.PROTECT_PDF],
          listener: (context, state) {
            final httpState=state.httpStates[HttpStates.PROTECT_PDF];
            if(httpState?.done==true){
              NotificationService.showSnackbar(text: "Protected file successfully",color: Colors.green);
              if(httpState?.extras?['savedFile'] is File) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':(httpState?.extras?['savedFile'] as File).path});
            }else if(httpState?.error!=null){
              NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
            }else if(httpState?.loading==true){
              NotificationService.showSnackbar(text: "Started file protection",color: Colors.lightBlue);
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Flex(
                    direction: Axis.vertical,
                    mainAxisSize: MainAxisSize.max,
                    children:[
                      // final Set<UserAccessPermission> user_access_permissions;//empty means user has owner permission
                      Expanded(
                        child: SingleChildScrollView(child: Column(
                            children: [
                              TextFormField(keyboardType: TextInputType.text,
                                  decoration: InputDecoration(labelText: "File name",border: OutlineInputBorder()),
                                  controller: outFileNameC),
                              SizedBox(height: 16,),
                              TextFormField(keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: "Owner Password",border: OutlineInputBorder()),
                                onChanged:(value) => setState(()=>ownerPassword=value),
                                validator:(value) {
                                  return value!=null && value.length>=10 ? null : "Min 10 character required";
                                } ,),
                              SizedBox(height: 16,),
                              TextFormField(keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: "User password",border: OutlineInputBorder()),
                                onChanged:(value) => setState(()=>userPassword=value),
                                validator:(value) {
                                  return value!=null && value.length>=10 ? null : "Min 10 character required";
                                } ,),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12,vertical: 16).copyWith(bottom: 10),
                                child: Flex(
                                  direction: Axis.vertical,
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ...[Text("User permissions",textAlign: TextAlign.center,style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold,decoration: TextDecoration.underline),),
                                      if(userPermissions.isEmpty) Text("⚠️ Will have owner permissions ⚠️")],
                                    ...UserAccessPermission.values.map((permission)=>Row(
                                      children: [
                                        Checkbox(tristate: false,value: userPermissions.contains(permission), onChanged: (hasPermission){
                                          setState(() {
                                            if(hasPermission==true) {
                                              userPermissions.add(permission);
                                            } else {
                                              userPermissions.removeWhere((permissionBit)=>permissionBit==permission);
                                            }
                                          });
                                        }),
                                        SizedBox(width: 12,),
                                        Text(permission.name.capitalize()),
                                      ],
                                    )),
                                  ],
                                ),)])),
                      ),
                      Container(
                        padding: EdgeInsets.all(16),
                        width: double.infinity,
                        child: FilledButton(onPressed: ownerPassword.length<10 || userPassword.length<10 ? null : _onProtectPdf, child: Text("Protect pdf")),
                      )
                    ],
                  ),
                ),
                if(state.isLoading(forr: HttpStates.PROTECT_PDF)) Expanded(child: Container(decoration: BoxDecoration(color: Colors.black54),child: Center(child: SpinKitThreeBounce(color: Colors.green,size: 45,),),))
              ],
            );
          },)
    );
  }

  void _onProtectPdf() async{
    bloc.add(ProtectPdfEvent(protectPdf: ProtectPdf(out_file_name: outFileNameC.text.isNotEmpty ? outFileNameC.text : "protected_file", owner_password: ownerPassword, user_password: userPassword, user_access_permissions: userPermissions.toSet(), file: await MultipartFile.fromFile(widget.file.path))));
  }
}
