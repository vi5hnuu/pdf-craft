import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

class ScannerScreen extends StatefulWidget {
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  DocumentScanner? _documentScanner;
  DocumentScanningResult? _result;
  late MediaQueryData md=MediaQuery.of(context);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0,vertical: 36),
        child: Center(
          child: Flex(
            direction: Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: ()=>startScan(DocumentFormat.pdf),
                    child: Column(
                      children: [
                        Image.asset('assets/icons/scan_document.webp',width: 80,fit: BoxFit.cover,),
                        const SizedBox(height: 8),
                        const Text("Scan PDF",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16),)
                      ],
                    ),
                  ),
                  const SizedBox(width: 24,),
                  GestureDetector(
                    onTap: ()=>startScan(DocumentFormat.jpeg),
                    child: Column(
                      children: [
                        Image.asset('assets/icons/scan_image.webp',width: 80,fit: BoxFit.cover,),
                        const SizedBox(height: 8),
                        const Text("Scan JPEG",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16),)
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 2,height: 64,endIndent: 16,indent: 16,),
              if(_result?.pdf!=null || _result?.images!=null)Padding(
                padding: EdgeInsets.only(
                    top: 16, bottom: 8, right: 8, left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text( _result!.pdf!=null ? 'Scanned PDF Document:':'Scanned Image/s:',style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18),),
                    FilledButton(onPressed: ()=>{},style: FilledButton.styleFrom(backgroundColor: Colors.green) ,child: Text( _result!.pdf!=null ? 'Save PDF:':'Merge to PDF',style: TextStyle(color: Colors.white),))
                  ],
                ),
              ),
              if (_result?.pdf != null) ...[
                SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: PDFView(
                    filePath: _result!.pdf!.uri,
                    enableSwipe: true,
                    swipeHorizontal: false,
                    autoSpacing: true,
                    pageFling: false,
                    fitEachPage: true,
                    backgroundColor: Colors.white,
                  ),
                )
              ],
              ...(_result?.images ?? []).map((image)=>Padding(
                padding: const EdgeInsets.all(8.0),
                child: (Image.file(File(_result!.images.first),fit: BoxFit.fitWidth)),
              ))
            ],
          ),
        ),
      ),
    );
  }

  void startScan(DocumentFormat format) async {
    try {
      _result = null;
      setState(() {});
      _documentScanner?.close();
      _documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: format,
          mode: ScannerMode.full,
          isGalleryImport: true,
          pageLimit: 10
        ),
      );
      _result = await _documentScanner?.scanDocument();
      setState(() {});
    } catch (e) {
      NotificationService.showSnackbar(text: "Failed to scan",color: Colors.red);
    }
  }

  @override
  void dispose() {
    _documentScanner?.close();
    super.dispose();
  }
}
