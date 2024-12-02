import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';

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
          PdfTool(onTap: () => router.pushNamed(AppRoutes.mergePdfRoute.name),assetFilePath: "assets/tools/merge-pdf.png",name: "Merge Pdf",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.reorderPdfPagesRoute.name),assetFilePath: "assets/tools/reorder-pdf.png",name: "Reorder Pdf",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.splitPdfRoute.name),assetFilePath: "assets/tools/split-pdf.png",name: "Split Pdf",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.pdfToJpgRoute.name),assetFilePath: "assets/tools/pdf-to-jpg.png",name: "Pdf to Jpg",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.imageToPdfRoute.name),assetFilePath: "assets/tools/image-to-pdf.png",name: "Image To Pdf",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.pageNumbersRoute.name),assetFilePath: "assets/tools/page-numbers.png",name: "Page Numbers",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.rotatePdfRoute.name),assetFilePath: "assets/tools/rotate-pdf.png",name: "Rotate Pdf",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.unprotectPdfRoute.name),assetFilePath: "assets/tools/unprotect-pdf.png",name: "Unprotect Pdf",),
          PdfTool(onTap: () => router.pushNamed(AppRoutes.protectPdfRoute.name),assetFilePath: "assets/tools/protect-pdf.png",name: "Protect Pdf",),
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
