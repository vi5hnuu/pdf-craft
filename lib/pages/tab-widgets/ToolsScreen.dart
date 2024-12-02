import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {

  @override
  Widget build(BuildContext context) {
    final router=GoRouter.of(context);

    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          PdfTool(onTap: () => router.pushNamed("merge-tool"),assetFilePath: "assets/tools/merge-pdf.png",name: "Merge Pdf",),
          PdfTool(assetFilePath: "assets/tools/reorder-pdf.png",name: "Reorder Pdf",),
          PdfTool(assetFilePath: "assets/tools/split-pdf.png",name: "Split Pdf",),
          PdfTool(assetFilePath: "assets/tools/pdf-to-jpg.png",name: "Pdf to Jpg",),
          PdfTool(assetFilePath: "assets/tools/image-to-pdf.png",name: "Image To Pdf",),
          PdfTool(assetFilePath: "assets/tools/page-numbers.png",name: "Page Numbers",),
          PdfTool(assetFilePath: "assets/tools/rotate-pdf.png",name: "Rotate Pdf",),
          PdfTool(assetFilePath: "assets/tools/unprotect-pdf.png",name: "Unprotect Pdf",),
          PdfTool(assetFilePath: "assets/tools/protect-pdf.png",name: "Protect Pdf",),
      ],),
    ));
  }
}

class PdfTool extends StatelessWidget {
  final String name;
  final String assetFilePath;
  final VoidCallback? onTap;

  const PdfTool({
    super.key,
    this.onTap,
    required this.name,
    required this.assetFilePath
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05),borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Image.asset(assetFilePath,fit: BoxFit.fitWidth,height: double.infinity,),),
          SizedBox(height: 12,),
          Text(name,style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16),)
        ],
      ),
    ));
  }
}
