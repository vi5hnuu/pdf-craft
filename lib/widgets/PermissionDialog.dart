import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/L10n.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';

class PermissionInfoDialog extends StatelessWidget {
  final Function(bool) onAction;

  PermissionInfoDialog({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.of(context).permissionRequest,textAlign: TextAlign.center,style: TextStyle(fontWeight: FontWeight.bold),),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.security,
            size: 48,
            color: Colors.blueAccent,
          ),
          SizedBox(height: 16),
          Text(
            L10n.of(context).permDialogIntro,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            L10n.of(context).permDialogBody,
            textAlign: TextAlign.justify,
          ),
          SizedBox(height: 8),
          Text(
            L10n.of(context).permDialogPrivacy,
            textAlign: TextAlign.justify,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: ()=>onAction(false),
          child: Text(L10n.of(context).decline),
        ),
        ElevatedButton(
          onPressed: () async =>onAction(await StoragePermissions.requestStoragePermissions()),
          child: Text(L10n.of(context).grantPermission),
        ),
      ],
    );
  }
}
