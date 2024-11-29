import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: GridView.count(crossAxisCount: 3,children: [
      Card(child: Text("Merge Pdf"),),
      Card(child: Text("mergePdf"),),
      Card(child: Text("reorderPdf"),),
      Card(child: Text("splitPdf"),),
      Card(child: Text("pdfToJpg"),),
      Card(child: Text("imageToPdf"),),
      Card(child: Text("pageNumbers"),),
      Card(child: Text("rotatePdf"),),
      Card(child: Text("unprotectPdf"),),
      Card(child: Text("protectpdf"),),
    ],));
  }
}
