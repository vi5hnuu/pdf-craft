import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/user-access-permission.dart';
import 'package:pdf_craft/models/request/protect-pdf.dart';
import 'package:pdf_craft/routes.dart';
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
  final TextEditingController nameC=TextEditingController();
  final TextEditingController ownerPasswordC=TextEditingController();
  final TextEditingController userPasswordC=TextEditingController();
  final List<UserAccessPermission> userPermissions=[];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Protect Pdf'),
        elevation: 5,
      ),
      body: BlocListener<PdfBloc,PdfState>(
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
          },child: Column(
          mainAxisSize: MainAxisSize.max,
          children:[
            // final Set<UserAccessPermission> user_access_permissions;//empty means user has owner permission
            TextFormField(controller: nameC),
            TextFormField(controller: ownerPasswordC),
            TextFormField(controller: userPasswordC),
            Column(
              children: [
                Text("User permissions (${userPermissions.isNotEmpty ? 'will have owner permissions ⚠️' : ''})"),
                ...UserAccessPermission.values.map((permission)=>Row(
                  children: [
                    Text(permission.name.capitalize()),
                    Checkbox(tristate: false,value: userPermissions.contains(permission), onChanged: (hasPermission){
                      if(hasPermission==true) {
                        userPermissions.add(permission);
                      } else {
                        userPermissions.removeWhere((permissionBit)=>permissionBit==permission);
                      }
                    })
                  ],
                )),
                FilledButton(onPressed: _onProtectPdf, child: Text("Protect pdf"))
              ],
            )
          ],
        ),)
    );
  }

  void _onProtectPdf() async{
    bloc.add(ProtectPdfEvent(protectPdf: ProtectPdf(out_file_name: "out_file_name", owner_password: ownerPasswordC.text, user_password: userPasswordC.text, user_access_permissions: userPermissions.toSet(), file: await MultipartFile.fromFile(widget.file.path))));
  }
}
