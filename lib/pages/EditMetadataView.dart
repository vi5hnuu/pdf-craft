import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/request/edit-metadata.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/httpStates.dart';

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
      appBar: AppBar(title: const Text('Edit Metadata'), elevation: 5),
      body: BlocConsumer<PdfBloc, PdfState>(
        buildWhen: (p, c) => p.httpStates[HttpStates.EDIT_METADATA] != c.httpStates[HttpStates.EDIT_METADATA],
        listenWhen: (p, c) => p.httpStates[HttpStates.EDIT_METADATA] != c.httpStates[HttpStates.EDIT_METADATA],
        listener: (context, state) {
          final s = state.httpStates[HttpStates.EDIT_METADATA];
          if (s?.done == true) {
            NotificationService.showSnackbar(text: 'Metadata updated successfully', color: Colors.green);
            if (s?.extras?['savedFile'] is File) {
              GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name, pathParameters: {'pdfFilePath': (s!.extras!['savedFile'] as File).path});
            }
          } else if (s?.error != null) {
            NotificationService.showSnackbar(text: s!.error!, color: Colors.red);
          } else if (s?.loading == true) {
            NotificationService.showSnackbar(text: 'Updating metadata...', color: Colors.lightBlue);
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
                            _field(_outFileNameC, 'Output File Name (optional)'),
                            const SizedBox(height: 12),
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Document Properties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            _field(_titleC,    'Title'),
                            const SizedBox(height: 12),
                            _field(_authorC,   'Author'),
                            const SizedBox(height: 12),
                            _field(_subjectC,  'Subject'),
                            const SizedBox(height: 12),
                            _field(_keywordsC, 'Keywords (comma-separated)'),
                            const SizedBox(height: 12),
                            _field(_creatorC,  'Creator Application'),
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
                        label: const Text('Save Metadata'),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isLoading(forr: HttpStates.EDIT_METADATA))
                Container(color: Colors.black54, child: const Center(child: SpinKitThreeBounce(color: Colors.green, size: 45))),
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
