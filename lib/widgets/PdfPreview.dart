import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

class PdfPreview extends StatefulWidget {
  final String pdfFilePath;
  final String? password;

  const PdfPreview({super.key, required this.pdfFilePath,this.password});

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  PdfControllerPinch? pdfController;
  late String? password=widget.password;
  String? docTitle;


  final errorLottie=ErrorView(subtitle: Text("Failed to Load Document",style: TextStyle(color: Colors.red,fontSize: 24,fontWeight: FontWeight.bold)));
  late final askPassError=Column(
    children: [
      errorLottie,
      FilledButton(onPressed: ()=>OpenFile.open(widget.pdfFilePath,type: Constants.extrnalOpenSupportedFiles['.${widget.pdfFilePath.split('.').last}'] ?? '*/*'), child: Text("Open in Other Apps",style: TextStyle(color: Colors.white),),style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),)
    ],
  );

  @override
  void initState() {
    _loadDocument();
    super.initState();
  }

  _loadDocument() async{
    pdfController?.dispose();
    try{
      final doc=await PdfDocument.openFile(widget.pdfFilePath,password: password);
    setState(()=>pdfController=PdfControllerPinch(viewportFraction: 1,document: Future.value(doc),initialPage: 1));
    }catch(e){
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text(
          docTitle ?? "Pdf View",
          overflow: TextOverflow.ellipsis,  // Ellipsis for long titles
        ),
        elevation: 5,
        actions: [
          if(pdfController!=null) ValueListenableBuilder<int?>(
            valueListenable: pdfController!.pageListenable,
            builder: (context, currentPage, child) {
              final totalPages = pdfController!.pagesCount ?? 1;
              final displayPage = currentPage ?? 1;
              return pdfController!.pagesCount==null ? const Text("") : Padding(
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
      floatingActionButton: FloatingActionButton(
        mini: true,
        tooltip: 'Share',
        onPressed: () => Share.shareXFiles([XFile(widget.pdfFilePath)]),
        child: const Icon(Icons.share),
      ),
      body: pdfController==null ? Center(child: askPassError,) : PdfViewPinch(
        controller: pdfController!,
        padding: 16,
        minScale: 1,
        maxScale:10,
        scrollDirection: Axis.vertical,
        onDocumentError: (error) => _askForPasswordAndRetry(context),
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
          errorBuilder: (_, error){
            return Center(child:askPassError);
          },
        ),
        onPageChanged: (page) {
          print('Current page: ${page}');
        },
      ),
    );
  }

  void _askForPasswordAndRetry(BuildContext context) async {
    final newPassword = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        String? tempPassword;
        return AlertDialog(
          title: const Text("Enter Password"),
          content: TextField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Password",
            ),
            onChanged: (value) => tempPassword = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(tempPassword),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    setState(()=>password = newPassword);
    _loadDocument();
  }

  @override
  void dispose() {
    pdfController?.dispose();
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
