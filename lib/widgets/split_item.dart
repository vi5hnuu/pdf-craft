import 'package:flutter/material.dart';
import 'package:pdf_craft/widgets/tool_error_state.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/split_pdf.dart';
import 'package:pdf_craft/models/thumbnail.dart';
import 'package:pdf_craft/theme/app_radius.dart';

class SplitItem extends StatelessWidget {
  final pageWidth=150.0;
  final RangeModel range;
  final Thumbnail startThumbnail;
  final Thumbnail? endThumbnail;
  final VoidCallback? onDelete;

  const SplitItem({
    super.key,
    required this.range,
    required this.startThumbnail,
    required this.endThumbnail,
    this.onDelete
  });

  /// Physical pixels a thumbnail occupies, so the JPEG is not decoded at full page size.
  int _thumbPx(BuildContext context) =>
      (pageWidth * MediaQuery.devicePixelRatioOf(context)).round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(children: [
      Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: pageWidth*1.4,
            width: pageWidth,
            decoration: BoxDecoration(border: Border.all(color: theme.dividerColor),borderRadius: BorderRadius.circular(AppRadius.surface)),
            child: (startThumbnail.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (startThumbnail.error!=null ? const ToolErrorState(compact: true) : Image.memory(startThumbnail.image!.bytes,fit: BoxFit.fitWidth,cacheWidth: _thumbPx(context),)),
          ),
          if(endThumbnail!=null) Column(
            children: [
              Text("${range.from+1}-${range.to+1}"),
              // theme.dividerColor, not Colors.white: on the light theme's white canvas this
              // connector between the two thumbnails was invisible.
              SizedBox(width: 50,child: Container(height: 2,decoration: BoxDecoration(color: theme.dividerColor),),)
            ],
          ),
          if(endThumbnail!=null) Container(
            height: pageWidth*1.4,
            width: pageWidth,
            decoration: BoxDecoration(border: Border.all(color: theme.dividerColor),borderRadius: BorderRadius.circular(AppRadius.surface)),
            child: (endThumbnail!.isLoading==true) ? const Center(child: CircularProgressIndicator(),) : (endThumbnail!.error!=null ? const ToolErrorState(compact: true) : Image.memory(endThumbnail!.image!.bytes,fit: BoxFit.fitWidth,cacheWidth: _thumbPx(context),)),
          )
        ],
      ),
      if(onDelete!=null) Positioned(top: 0,right: 30,child: IconButton(onPressed: onDelete, tooltip: L10n.of(context).delete, icon: Icon(Icons.delete,color: Theme.of(context).colorScheme.error,),))
    ],);
  }
}
