import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/models/request/image-to-pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';
import 'package:pdf_craft/widgets/PdfPreview.dart';
import 'package:pdf_craft/widgets/LoadingOverlay.dart';

class ScannerScreen extends StatefulWidget {
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late GoRouter router=GoRouter.of(context);
  DocumentScanner? _documentScanner;
  DocumentScanningResult? _result;
  late MediaQueryData md=MediaQuery.of(context);
  TextEditingController outFileNameC=TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PdfBloc,PdfState>(
        listener: (context, state) {
          final httpState=state.httpStates[HttpStates.IMAGE_TO_PDF];
          if(httpState?.done==true){
            final savedFile=httpState?.extras?['savedFile'];
            NotificationService.showSnackbar(text: "Image to pdf Successfull",color: Colors.green);
            if(savedFile is File){
              OpenFile.open(savedFile.path,type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(savedFile)] ?? '*/*');
            }
            setState(()=>_result=null);
          }else if(httpState?.error!=null){
            NotificationService.showSnackbar(text: httpState!.error!,color: Colors.red);
          }else if(httpState?.loading==true){
            NotificationService.showSnackbar(text: "Merging image/s to pdf",color: Colors.lightBlue);
          }
        },
        listenWhen: (previous, current) => previous.httpStates[HttpStates.IMAGE_TO_PDF]!=current.httpStates[HttpStates.IMAGE_TO_PDF],
        buildWhen: (previous, current) => previous.httpStates[HttpStates.IMAGE_TO_PDF]!=current.httpStates[HttpStates.IMAGE_TO_PDF],
        builder: (context, state) {
      return Stack(children: [
        Column(children: [
        Expanded(child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0,vertical: 36),
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
                      FilledButton(onPressed: _result!=null ? ()=>_saveResult(_result!) : null,style: FilledButton.styleFrom(backgroundColor: Colors.green) ,child: Text( _result!.pdf!=null ? 'Save PDF:':'Merge to PDF'))
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0).copyWith(bottom: 12),
                  child: TextFormField(keyboardType: TextInputType.text,
                    decoration: InputDecoration(labelText: "Output File Name",border: OutlineInputBorder()),
                    controller: outFileNameC),
                ),
                if (_result?.pdf != null) ...[
                  Container(
                    height: 400,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: PDFView(
                        filePath: _result!.pdf!.uri,
                        enableSwipe: true,
                        swipeHorizontal: true,
                        autoSpacing: true,
                        pageFling: true,
                        fitEachPage: true,
                        defaultPage: 1,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  )
                ],
                if(_result?.images?.isNotEmpty==true)SizedBox(
                  height: md.size.height*0.6,
                  child: ListView.builder(itemCount: _result?.images?.length ?? 0,itemBuilder: (context, index) {
                    final img=_result!.images![index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: (Image.file(File(img),fit: BoxFit.fitHeight,)),
                    );
                  },),
                )
              ],
            ),
          ),
        )),
        const BannerAdd(),
        ]),
        LoadingOverlay(httpState: state.httpStates[HttpStates.IMAGE_TO_PDF]),
      ],) ;
    });
  }

  void startScan(DocumentFormat format) async {
    try {
      _result = null;
      setState(() {});
      _documentScanner?.close();
      _documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {format},
          mode: ScannerMode.full,
          isGalleryImport: true,
          pageLimit: 10,
        ),
      );
      _result = await _documentScanner?.scanDocument();
      AdsSingleton().dispatch(LoadInterstitialAd());
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

  void _saveResult(DocumentScanningResult result) async {
    final fileName=outFileNameC.text.isEmpty ? "scanned-${DateTime.now().millisecondsSinceEpoch}" : outFileNameC.text;
    if(result.pdf!=null) {
      await _savePdf(result.pdf!,fileName);
      setState(()=>_result=null);
    } else {
      BlocProvider.of<PdfBloc>(context).add(ImageToPdfEvent(imageToPdf: ImageToPdf(out_file_name: fileName, files: await Future.wait((result.images ?? []).map((imagePath)=>MultipartFile.fromFile(imagePath))))));
    }
  }

  Future<void> _savePdf(DocumentScanningResultPdf pdf,String fileName) async {
    try {
      final Directory rootDir = Directory(Constants.processedDirPath);
      if (!await rootDir.exists()) {
        await rootDir.create(
            recursive: true); // Create the directory if it doesn't exist
      }
      // Copy the scanned PDF to the target directory
      final File sourceFile = File.fromUri(Uri.file(pdf.uri));
      final File targetFile = await sourceFile.copy('${Constants.processedDirPath}/${fileName}.pdf');

      NotificationService.showSnackbar(
        text: 'File saved at: ${targetFile.path}',
        color: Colors.green,
      );
      OpenFile.open(sourceFile.path,type: Constants.extrnalOpenSupportedFiles['.pdf']);
    } catch (e) {
      NotificationService.showSnackbar(
        text: 'Failed to save the file: $e',
        color: Colors.red,
      );
    }
  }
}
