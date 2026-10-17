import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/unlock_pdf.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/utils/tool_view_mixin.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/tool_pane.dart';

class UnProtectPdfView extends StatefulWidget {
  final File file;
  final String? outFileName;

  const UnProtectPdfView({super.key, required this.file, this.outFileName});

  @override
  State<UnProtectPdfView> createState() => _UnProtectPdfViewState();
}

class _UnProtectPdfViewState extends State<UnProtectPdfView>
    with ToolResultHandler, ToolViewMixin {
  late PdfBloc bloc=BlocProvider.of<PdfBloc>(context);
  TextEditingController outputFileNameC=TextEditingController();
  String password="";
  // The password is masked by default, with a show/hide toggle.
  bool _obscure = true;

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
    resetToolState([HttpStates.unprotectPdf]);
  }

  @override
  void dispose() {
    outputFileNameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ToolStrings.name(context, 'unprotect')),
        elevation: 5,
      ),
      body: ToolPane(child: BlocConsumer<PdfBloc,PdfState>(
        buildWhen: (previous, current) => previous.httpStates[HttpStates.unprotectPdf]!=current.httpStates[HttpStates.unprotectPdf],
        listenWhen: (previous, current) => previous.httpStates[HttpStates.unprotectPdf]!=current.httpStates[HttpStates.unprotectPdf],
          listener: (context, state) => handleToolState(
            state.httpStates[HttpStates.unprotectPdf], successMessage: L10n.current.toolDone),
          builder: (context, state) {
           return Stack(
             children:[
               Padding(
                 padding: const EdgeInsets.all(12),
                 child: Column(
                   mainAxisSize: MainAxisSize.max,
                   children:[
                     TextFormField(keyboardType: TextInputType.text,
                       decoration: InputDecoration(labelText: L10n.of(context).outputFileName,border: const OutlineInputBorder()),
                       controller: outputFileNameC,),
                     const SizedBox(height: 12,),
                     TextFormField(
                         keyboardType: TextInputType.visiblePassword,
                         obscureText: _obscure,
                         autocorrect: false,
                         enableSuggestions: false,
                         decoration: InputDecoration(
                           labelText: L10n.of(context).passwordLabel,
                           border: const OutlineInputBorder(),
                           suffixIcon: IconButton(
                             tooltip: _obscure ? L10n.of(context).showPassword : L10n.of(context).hidePassword,
                             icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                             onPressed: () => setState(() => _obscure = !_obscure),
                           ),
                         ),
                         onChanged: (value) => setState(()=>password=value)),
                     const SizedBox(height: 16,),
                     FilledButton(onPressed: password.isEmpty ? null : _onUnProtectPdf, child: Text(L10n.of(context).removePassword))
                   ],
                 ),
               ),
               processingOverlay(state.httpStates[HttpStates.unprotectPdf], label: L10n.of(context).procWorking),
             ],
           );
          },)),
    );
  }

  void _onUnProtectPdf() async{
    final uploadFile = await readForUpload(widget.file);
    if (uploadFile == null) return;
    if (!mounted) return;
    runTool((cancelToken) => UnprotectPdfEvent(unlockPdf: UnProtectPdf(outFileName: outputFileNameC.text.isEmpty ? "protected" : outputFileNameC.text, password: password, file: uploadFile), cancelToken: cancelToken));
  }
}
