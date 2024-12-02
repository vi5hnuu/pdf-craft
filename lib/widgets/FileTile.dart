import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/utils/utility.dart';

class FileTile extends StatelessWidget {
  final FileSystemEntity file;
  final bool enabled;
  final bool selected;
  final VoidCallback? onPress;
  const FileTile({super.key,required this.file,this.enabled=true,this.selected=false,this.onPress});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        enabled: enabled,
        selected: selected,
        selectedTileColor: Colors.green.withOpacity(0.15),
        selectedColor: Colors.green,
        leading: file is Directory
            ? const Icon(FontAwesomeIcons.solidFolder,
            color: Colors.yellowAccent)
            : const Icon(FontAwesomeIcons.file,
            color: Colors.orange),
        title: Text(file.path.split('/').last),
        subtitle: (file is! Directory) ? Text(Utility.bytesToSize(File(file.path).lengthSync())) : null,
        onTap:onPress
    );
  }
}