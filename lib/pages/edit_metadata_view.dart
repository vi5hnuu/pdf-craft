import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/tool_strings.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/request/edit_metadata.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/http_states.dart';
import 'package:pdf_craft/widgets/loading_overlay.dart';

class EditMetadataView extends StatefulWidget {
  final File file;
  const EditMetadataView({super.key, required this.file});

  @override
  State<EditMetadataView> createState() => _EditMetadataViewState();
}

class _EditMetadataViewState extends State<EditMetadataView> {
  late final PdfBloc _bloc = BlocProvider.of<PdfBloc>(context);
  final _outFileNameC = TextEditingController();
  final _titleC      = TextEditingController();
  final _authorC     = TextEditingController();
  final _subjectC    = TextEditingController();
  final _keywordsC   = TextEditingController();
  final _creatorC    = TextEditingController();
  final _producerC   = TextEditingController();

  @override
  void initState() {
    AdsSingleton().dispatch(LoadInterstitialAd());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ToolStrings.name(context, 'edit-metadata')), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.editMetadata] != c.httpStates[HttpStates.editMetadata],
        listenWhen: (p, c) => p.httpStates[HttpStates.editMetadata] != c.httpStates[HttpStates.editMetadata],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.editMetadata];
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
                            _field(_outFileNameC, L10n.of(context).outputFileNameOptional),
                            const SizedBox(height: 12),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(L10n.of(context).documentProperties, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            _field(_titleC,    'Title'),
                            const SizedBox(height: 12),
                            _field(_authorC,   'Author'),
                            const SizedBox(height: 12),
                            _field(_subjectC,  'Subject'),
                            const SizedBox(height: 12),
                            _field(_keywordsC, L10n.of(context).keywordsCommaSeparated),
                            const SizedBox(height: 12),
                            _field(_creatorC,  L10n.of(context).creatorApplication),
                            const SizedBox(height: 12),
                            _field(_producerC, 'Producer'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _onSave,
                        icon: const Icon(Icons.save),
                        label: Text(L10n.of(context).saveMetadata),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingOverlay(httpState: state.httpStates[HttpStates.editMetadata], label: L10n.of(context).procWorking),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  void _onSave() async {
    _bloc.add(EditMetadataEvent(
      editMetadata: EditMetadata(
        outFileName: _outFileNameC.text.isNotEmpty ? _outFileNameC.text : null,
        title:    _titleC.text.isNotEmpty    ? _titleC.text    : null,
        author:   _authorC.text.isNotEmpty   ? _authorC.text   : null,
        subject:  _subjectC.text.isNotEmpty  ? _subjectC.text  : null,
        keywords: _keywordsC.text.isNotEmpty ? _keywordsC.text : null,
        creator:  _creatorC.text.isNotEmpty  ? _creatorC.text  : null,
        producer: _producerC.text.isNotEmpty ? _producerC.text : null,
        file: await MultipartFile.fromFile(widget.file.path),
      ),
    ));
  }

  @override
  void dispose() {
    for (final c in [_outFileNameC, _titleC, _authorC, _subjectC, _keywordsC, _creatorC, _producerC]) {
      c.dispose();
    }
    super.dispose();
  }
}
