import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
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

  @override
  void initState() {
    pdfController = PdfControllerPinch(document: PdfDocument.openFile(widget.pdfFilePath,password: widget.password),initialPage: 1);
    super.initState();
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
          ValueListenableBuilder<int?>(
            valueListenable: pdfController.pageListenable,
            builder: (context, currentPage, child) {
              final totalPages = pdfController.pagesCount ?? 1;
              final displayPage = currentPage ?? 1;
              return Padding(
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
        onDocumentError: (error) => const Center(child: Text("Failed to load document"),),
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
          errorBuilder: (_, error) => Center(child: Text(error.toString())),
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
