import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/utils/storage_permissions.dart';

class PermissionInfoDialog extends StatelessWidget {
  final Function(bool) onAction;

  const PermissionInfoDialog({super.key, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.of(context).permissionRequest,textAlign: TextAlign.center,style: const TextStyle(fontWeight: FontWeight.bold),),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.security,
            size: 48,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          Text(
            L10n.of(context).permDialogIntro,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            L10n.of(context).permDialogBody,
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 8),
          Text(
            L10n.of(context).permDialogPrivacy,
            textAlign: TextAlign.justify,
            style: const TextStyle(color: Colors.grey),
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
