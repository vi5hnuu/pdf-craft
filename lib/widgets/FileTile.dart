import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';

class FileTile extends StatelessWidget {
  final FileSystemEntity file;
  final bool enabled;
  final bool selected;
  final VoidCallback? onPress;
  final VoidCallback? onDelete;

  const FileTile(
      {super.key,
      required this.file,
      this.enabled = true,
      this.selected = false,
      this.onPress,
      this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fileIcon = Constants.fileIcons[
        file is Directory ? 'folder' : file.path.split('.').last];

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    String? dateStr;
    String? sizeStr;
    if (file is File) {
      final stat = File(file.path).statSync();
      final d = stat.modified;
      dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
      sizeStr = Utility.bytesToSize(File(file.path).lengthSync());
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        enabled: enabled,
        selected: selected,
        selectedTileColor: primary.withOpacity(0.12),
        selectedColor: primary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: fileIcon != null
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(fileIcon, fit: BoxFit.contain),
                )
              : Icon(
                  file is Directory
                      ? FontAwesomeIcons.solidFolder
                      : FontAwesomeIcons.file,
                  color: primary,
                  size: 20,
                ),
        ),
        title: Text(
          file.path.split('/').last,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: file is File && sizeStr != null && dateStr != null
            ? Text(
                '$sizeStr  •  $dateStr',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              )
            : null,
        trailing: file is File
            ? (onDelete != null
                ? IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        color: Colors.red.shade300),
                    splashRadius: 20,
                  )
                : null)
            : Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.5)),
        onTap: onPress,
      ),
    );
  }
}
