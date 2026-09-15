import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/L10n.dart';
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
        ListTile(enabled: widget.type!=SplitType.EXTRACT_ALL_PAGES,onTap: widget.type==SplitType.EXTRACT_ALL_PAGES ? null : ()=>widget.onSplitSelect(SplitType.SPLIT_BY_RANGE),title: Text(L10n.of(context).splitByRanges),subtitle: Text(L10n.of(context).splitByRangesSub),),
        ListTile(enabled: widget.type!=SplitType.EXTRACT_ALL_PAGES,onTap: widget.type==SplitType.EXTRACT_ALL_PAGES ? null : ()=>widget.onSplitSelect(SplitType.FIXED_RANGE),title: Text(L10n.of(context).fixedRanges),subtitle: Text(L10n.of(context).fixedRangesSub),),
        ListTile(enabled: widget.type!=SplitType.EXTRACT_ALL_PAGES,onTap: widget.type==SplitType.EXTRACT_ALL_PAGES ? null : ()=>widget.onSplitSelect(SplitType.DELETE_PAGES),title: Text(L10n.of(context).deletePagesTitle),subtitle: Text(L10n.of(context).deletePagesSub),),
        ListTile(enabled: widget.type!=SplitType.EXTRACT_ALL_PAGES,onTap: widget.type==SplitType.EXTRACT_ALL_PAGES ? null : ()=>widget.onSplitSelect(SplitType.SPLIT_BY_BOOKMARK),title: Text(L10n.of(context).splitByBookmark),subtitle: Text(L10n.of(context).splitByBookmarkSub),),
        ListTile(trailing: Checkbox(value: widget.type==SplitType.EXTRACT_ALL_PAGES, onChanged: (value)=>widget.onSplitSelect(value==true ? SplitType.EXTRACT_ALL_PAGES : null)),title: Text(L10n.of(context).extractAllPages),subtitle: Text(L10n.of(context).extractAllPagesSub),),
      ],
    ));
  }
}
