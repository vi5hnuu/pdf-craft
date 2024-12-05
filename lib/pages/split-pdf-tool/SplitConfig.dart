import 'package:flutter/material.dart';
import 'package:pdf_craft/models/enums/split-type.dart';

class SplitConfig extends StatefulWidget {
  final SplitType? type;
  final Function(SplitType? type) onSplitSelect;

  const SplitConfig({super.key,this.type,required this.onSplitSelect});

  @override
  State<SplitConfig> createState() => _SplitConfigState();
}
class _SplitConfigState extends State<SplitConfig> {
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(
      children: [
        ListTile(onTap: widget.type==SplitType.EXTRACT_ALL_PAGES ? null : ()=>widget.onSplitSelect(SplitType.SPLIT_BY_RANGE),title: Text("Split by ranges"),subtitle: Text("Add custom ranges"),),
        ListTile(onTap: widget.type==SplitType.EXTRACT_ALL_PAGES ? null : ()=>widget.onSplitSelect(SplitType.FIXED_RANGE),title: Text("Fixed ranges"),subtitle: Text("Assign a fixed range"),),
        ListTile(onTap: widget.type==SplitType.EXTRACT_ALL_PAGES ? null : ()=>widget.onSplitSelect(SplitType.DELETE_PAGES),title: Text("Delete pages"),subtitle: Text("Remove individual pages or range of pages"),),
        ListTile(trailing: Checkbox(value: widget.type==SplitType.EXTRACT_ALL_PAGES, onChanged: (value)=>widget.onSplitSelect(value==true ? SplitType.EXTRACT_ALL_PAGES : null)),title: Text("Extract all pages"),subtitle: Text("Every page will be converted to a seperate PDF file, a total of 19 PDF will be generated"),),
      ],
    ));
  }
}
