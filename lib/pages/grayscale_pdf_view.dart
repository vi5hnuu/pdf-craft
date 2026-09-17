import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/grayscale_pdf.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/loading_overlay.dart';
import 'package:pdf_craft/widgets/page_range_selector.dart';

class GrayscalePdfView extends StatefulWidget {
  final File file;

  const GrayscalePdfView({super.key, required this.file});

  @override
  State<GrayscalePdfView> createState() => _GrayscalePdfViewState();
}

class _GrayscalePdfViewState extends State<GrayscalePdfView> {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();

  /// 0-indexed pages to convert. Empty means the whole document.
  final Set<int> _pages = <int>{};

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'grayscale')), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.grayscalePdf] != c.httpStates[HttpStates.grayscalePdf],
        listenWhen: (p, c) => p.httpStates[HttpStates.grayscalePdf] != c.httpStates[HttpStates.grayscalePdf],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.grayscalePdf];
          if (s?.done == true) {
          AdsSingleton().dispatch(ShowInterstitialAd());
            NotificationService.showSnackbar(text: L10n.current.grayscaleDone, color: Colors.green);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.of(context).grayscaleExplainer,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _outFileNameC,
                      decoration: InputDecoration(labelText: L10n.of(context).outputFileName, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    PageRangeSelector(
                      file: widget.file,
                      selected: _pages,
                      onChanged: (pages) => setState(() {
                        _pages
                          ..clear()
                          ..addAll(pages);
                      }),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: _onGrayscale, child: Text(ToolStrings.name(context, 'grayscale'))),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.grayscalePdf], label: L10n.of(context).procWorking),
            ],
          );
        },
      ),
    );
  }

  void _onGrayscale() async {
    bloc.add(GrayscalePdfEvent(
      grayscalePdf: GrayscalePdf(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'grayscale_file',
        pages: _pages.toList()..sort(),
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    super.dispose();
  }
}
