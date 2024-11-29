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
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(crossAxisCount: 3,
        children: [
          PdfTool(name: "Merge Pdf",),
          PdfTool(name: "Reorder Pdf",),
          PdfTool(name: "Split Pdf",),
          PdfTool(name: "Pdf To Jpg",),
          PdfTool(name: "Image To Pdf",),
          PdfTool(name: "Page Numbers",),
          PdfTool(name: "Rotate Pdf",),
          PdfTool(name: "Unprotect Pdf",),
          PdfTool(name: "Protect Pdf",),
      ],),
    ));
  }
}

class PdfTool extends StatelessWidget {
  final String name;

  const PdfTool({
    super.key,
    required this.name
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(child: Card(child: Padding(padding: EdgeInsets.all(8),child: Text(name),),elevation: 0.1,borderOnForeground: true));
  }
}
