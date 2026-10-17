import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/theme/app_spacing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/extract_text.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/page_range_selector.dart';
import 'package:pdf_craft/widgets/tool_pane.dart';

class ExtractTextView extends StatefulWidget {
  final File file;

  const ExtractTextView({super.key, required this.file});

  @override
  State<ExtractTextView> createState() => _ExtractTextViewState();
}

class _ExtractTextViewState extends State<ExtractTextView>
    with ToolResultHandler, ToolViewMixin {
  late PdfBloc bloc = BlocProvider.of<PdfBloc>(context);
  final TextEditingController _outFileNameC = TextEditingController();
  /// 0-indexed pages the tool applies to. Empty means the whole document.
  final Set<int> _pages = <int>{};


  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    resetToolState([HttpStates.extractText]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'extract-text'))),
      body: ToolPane(child: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.extractText] != c.httpStates[HttpStates.extractText],
        listenWhen: (p, c) => p.httpStates[HttpStates.extractText] != c.httpStates[HttpStates.extractText],
        // The output is a .txt, not a PDF, so it opens externally instead of in our viewer.
        listener: (context, state) => handleToolState(
              state.httpStates[HttpStates.extractText],
              successMessage: L10n.current.toolDone,
              onDone: (saved) => OpenFile.open(saved.path),
            ),
        builder: (context, state) {
          return Stack(
            children: [
              Column(children: [
                Expanded(
                  // Scrollable: this was a fixed Column holding a text field and the page
                  // selector's 260dp grid, about 530dp of content against the ~290dp left when
                  // the keyboard opens for the filename, and the Spacer could not absorb it.
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.of(context).extractTextHint,
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
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: FilledButton(onPressed: _onExtract, child: Text(ToolStrings.name(context, 'extract-text'))),
                ),
              ]),
              processingOverlay(state.httpStates[HttpStates.extractText], label: L10n.of(context).procWorking),
            ],
          );
        },
      )),
    );
  }

  void _onExtract() async {
    final file = await readForUpload(widget.file);
    if (file == null) return;
    runTool((cancelToken) => ExtractTextEvent(
      extractText: ExtractText(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : 'extracted_text',
        pages: _pages.toList()..sort(),
        file: file,
      ),
      cancelToken: cancelToken,
    ));
  }

  @override
  void dispose() {
    _outFileNameC.dispose();
    super.dispose();
  }
}
