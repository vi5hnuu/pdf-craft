import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/user_access_permission.dart';

class ProtectPdf {
  final String outFileName;
  final String ownerPassword;
  final String userPassword;
  final Set<UserAccessPermission> userAccessPermissions;//empty means user has owner permission
  final MultipartFile file;

  ProtectPdf({required this.outFileName,required this.ownerPassword,required this.userPassword,required this.userAccessPermissions,required this.file});

  Map<String,dynamic> toJson() {
    return {
      "protect-pdf-info":MultipartFile.fromString(jsonEncode({
        'out_file_name':outFileName,
        'owner_password':ownerPassword,
        'user_password':userPassword,
        'user_access_permissions':userAccessPermissions.map((perm)=>perm.bit).toList(),
      }),contentType: DioMediaType.parse("application/json")),
    'file':file,
    };
  }
}