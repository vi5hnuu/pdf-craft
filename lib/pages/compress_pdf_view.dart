import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/enum_labels.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/enums/compression_level.dart';
import 'package:pdf_craft/models/request/compress_pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/loading_overlay.dart';

class CompressPdfView extends StatefulWidget {
  final File file;

  const CompressPdfView({super.key, required this.file});

  @override
  State<CompressPdfView> createState() => _CompressPdfViewState();
}

class _CompressPdfViewState extends State<CompressPdfView> {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();
  CompressionLevel _level = CompressionLevel.RECOMMENDED;
  // Token for the in-flight request so the overlay's Cancel can abort it.
  CancelToken? _cancelToken;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'compress')), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.compressPdf] != c.httpStates[HttpStates.compressPdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.compressPdf] != c.httpStates[HttpStates.compressPdf],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.compressPdf];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: L10n.current.toolDone, color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _outFileNameC,
                              decoration: InputDecoration(labelText: L10n.of(context).outputFileName, border: const OutlineInputBorder()),
                            ),
                            const SizedBox(height: 24),
                            Text(L10n.of(context).compressionLevel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            // RadioGroup supplies the selection to the tiles below it, and
                            // gives the set arrow-key navigation that loose radios never had.
                            RadioGroup<CompressionLevel>(
                              groupValue: _level,
                              onChanged: (v) => setState(() => _level = v ?? _level),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: CompressionLevel.values
                                    .map((level) => RadioListTile<CompressionLevel>(
                                          title: Text(level.localizedLabel(context)),
                                          value: level,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _onCompress,
                        child: Text(ToolStrings.name(context, 'compress')),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(
                httpState: state.httpStates[HttpStates.compressPdf],
                label: L10n.of(context).compressingPdf,
                onCancel: () => _cancelToken?.cancel('cancelled-by-user'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onCompress() async {
    _cancelToken = CancelToken();
    final file = await MultipartFile.fromFile(widget.file.path);
    bloc.add(CompressPdfEvent(
      compressPdf: CompressPdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'compressed_file',
        level: _level,
        file: file,
      ),
      cancelToken: _cancelToken,
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    super.dispose();
  }
}
