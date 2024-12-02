import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/user-access-permission.dart';
import 'package:pdf_craft/pages/PdfToJpgView.dart';
import 'package:pdf_craft/utils/utility.dart';

class UnProtectPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  // const MergePdfView({super.key,required this.files,this.outFileName}):assert(files.length>1);
  UnProtectPdfView({super.key, required this.file, this.outFileName}) {
  }

  @override
  State<UnProtectPdfView> createState() => _UnProtectPdfViewState();
}

class _UnProtectPdfViewState extends State<UnProtectPdfView> {
  final TextEditingController passwordC=TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('UnProtect Pdf'),
        elevation: 5,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children:[
          // final Set<UserAccessPermission> user_access_permissions;//empty means user has owner permission
          TextFormField(controller: passwordC),
          FilledButton(onPressed: (){}, child: Text("Remove password"))
        ],
      ),
    );
  }
}
