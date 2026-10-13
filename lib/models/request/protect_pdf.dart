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
        // Names, not PDF bits. Sent as bits, Jackson read them as ordinals: 9-12 were out of
        // range and failed, while 0 and 3-6 were valid indices and silently selected a
        // *different* permission than the user picked.
        'user_access_permissions':userAccessPermissions.map((perm)=>perm.name).toList(),
      }),contentType: DioMediaType.parse("application/json")),
    'file':file,
    };
  }
}