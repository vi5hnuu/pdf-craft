import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/extensions/string-etension.dart';
import 'package:pdf_craft/models/enums/user-access-permission.dart';
import 'package:pdf_craft/pages/PdfToJpgView.dart';
import 'package:pdf_craft/utils/utility.dart';

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
  final TextEditingController nameC=TextEditingController();
  final TextEditingController ownerPasswordC=TextEditingController();
  final TextEditingController userPasswordC=TextEditingController();
  final List<int> userPermissions=[];

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
      body: Column(
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
                  Checkbox(tristate: false,value: userPermissions.contains(permission.bit), onChanged: (hasPermission){
                    if(hasPermission==true) {
                      userPermissions.add(permission.bit);
                    } else {
                      userPermissions.removeWhere((permissionBit)=>permissionBit==permission.bit);
                    }
                  })
                ],
              )),
              FilledButton(onPressed: (){}, child: Text("Protect pdf"))
            ],
          )
        ],
      ),
    );
  }
}
