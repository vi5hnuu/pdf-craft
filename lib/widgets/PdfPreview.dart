import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pdfx/pdfx.dart';

class PdfPreview extends StatefulWidget {
  final String pdfFilePath;
  final String? password;

  const PdfPreview({super.key, required this.pdfFilePath,this.password});

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  late PdfControllerPinch pdfController;
  String? docTitle;


  final errorLottie=ErrorView(subtitle: Text("Failed to Load Document",style: TextStyle(color: Colors.red,fontSize: 24,fontWeight: FontWeight.bold)));

  @override
  void initState() {
    pdfController = PdfControllerPinch(document: PdfDocument.openFile(widget.pdfFilePath,password: widget.password),initialPage: 1);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:  Text(
          docTitle ?? "Pdf View",
          overflow: TextOverflow.ellipsis,  // Ellipsis for long titles
        ),
        elevation: 5,
        actions: [
          ValueListenableBuilder<int?>(
            valueListenable: pdfController.pageListenable,
            builder: (context, currentPage, child) {
              final totalPages = pdfController.pagesCount ?? 1;
              final displayPage = currentPage ?? 1;
              return pdfController.pagesCount==null ? const Text("") : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    '$displayPage / $totalPages',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: pdfController,
        padding: 16,
        minScale: 1,
        maxScale:10,
        scrollDirection: Axis.vertical,
        onDocumentError: (error) => Center(child: errorLottie,),
        onDocumentLoaded: (document) {
          setState(()=>docTitle=document.sourceName.split('/').last);
        },
        builders:  PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: DefaultBuilderOptions(
            loaderSwitchDuration: const Duration(seconds: 1),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(opacity: animation, child: child),
          ),
          documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) => Center(child: errorLottie),
        ),
        onPageChanged: (page) {
          print('Current page: ${page}');
        },
      ),
    );
  }

  @override
  void dispose() {
    pdfController.dispose();
    super.dispose();
  }
}

class ErrorView extends StatelessWidget {
  final Widget? subtitle;

  const ErrorView({
    super.key,
    this.subtitle
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 75,vertical: 125),
      child:Column(
        children: [
          LottieBuilder.asset("assets/lottie/error.json",fit: BoxFit.fitWidth,animate: true,backgroundLoading: true,),
          if(subtitle!=null) subtitle!
        ],
      ),
    );
  }
}
