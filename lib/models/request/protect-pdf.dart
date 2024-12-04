import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pdf_craft/models/enums/user-access-permission.dart';

class ProtectPdf {
  final String out_file_name;
  final String owner_password;
  final String user_password;
  final Set<UserAccessPermission> user_access_permissions;//empty means user has owner permission
  final MultipartFile file;

  ProtectPdf({required this.out_file_name,required this.owner_password,required this.user_password,required this.user_access_permissions,required this.file});

  Map<String,dynamic> toJson() {
    return {
      "protect-pdf-info":MultipartFile.fromString(jsonEncode({
        'out_file_name':out_file_name,
        'owner_password':owner_password,
        'user_password':user_password,
        'user_access_permissions':user_access_permissions.map((perm)=>perm.bit).toList(),
      }),contentType: DioMediaType.parse("application/json")),
    'file':file,
    };
  }
}