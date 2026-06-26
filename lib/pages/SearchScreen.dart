import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/BannerAdd.dart';
import 'package:pdf_craft/widgets/FileTile.dart';
import 'package:rxdart/rxdart.dart';

/// File search across device storage. The query is debounced (500ms) and the
/// underlying bloc cancels any in-flight search when a new query arrives and
/// caps the number of results, so typing stays responsive. Results can be
/// further narrowed client-side by file type.
class SearchScreen extends StatefulWidget {
  SearchScreen({
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _TypeFilter { all, pdf, images, docs }

class _SearchScreenState extends State<SearchScreen> {
  late FilesBloc bloc = BlocProvider.of<FilesBloc>(context);
  final BehaviorSubject<String> searchSubject = BehaviorSubject();
  _TypeFilter _typeFilter = _TypeFilter.all;

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
  static const _docExts = ['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'];

  @override
  void initState() {
    searchSubject
        .debounceTime(const Duration(milliseconds: 500))
        .listen((value) {
      if (!mounted) return;
      if (value.isNotEmpty) {
        bloc.add(SearchFileEvent(
            path: Constants.rootStoragePath, nameLike: value));
      } else {
        bloc.add(const ResetSearchEvent());
      }
    }, cancelOnError: false);
    super.initState();
  }

  bool _matchesType(File file) {
    final ext = Utility.fileExtension(file).toLowerCase();
    switch (_typeFilter) {
      case _TypeFilter.all:
        return true;
      case _TypeFilter.pdf:
        return ext == '.pdf';
      case _TypeFilter.images:
        return _imageExts.contains(ext);
      case _TypeFilter.docs:
        return _docExts.contains(ext);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 5,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            "assets/logo.webp",
            fit: BoxFit.fitWidth,
            width: 124,
          ),
        ),
        leadingWidth: 112,
        bottom: PreferredSize(
          preferredSize: const Size(double.infinity, 108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: TextFormField(
                  autofocus: true,
                  onChanged: (value) => searchSubject.sink.add(value),
                  enableSuggestions: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search files',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (final t in _TypeFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_typeLabel(t)),
                          selected: _typeFilter == t,
                          onSelected: (_) => setState(() => _typeFilter = t),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: BlocBuilder<FilesBloc, FilesState>(
        buildWhen: (previous, current) =>
            previous.searchStream != current.searchStream,
        builder: (context, state) {
          final searchStream = state.searchStream;
          return Flex(
            direction: Axis.vertical,
            children: [
              Expanded(
                child: searchStream == null
                    ? _hint(theme, 'Try searching something')
                    : StreamBuilder<List<File>>(
                        stream: searchStream,
                        builder: (context, snapshot) {
                          final all = snapshot.data ?? const [];
                          final results =
                              all.where(_matchesType).toList(growable: false);
                          if (results.isEmpty) {
                            return _hint(theme, 'No matching files');
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8),
                                child: Text(
                                  "${results.length} file(s) found",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: results.length,
                                  itemBuilder: (context, index) {
                                    final file = results[index];
                                    return FileTile(
                                        file: file,
                                        onPress: () => _openFile(file));
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const BannerAdd()
            ],
          );
        },
      ),
    );
  }

  Widget _hint(ThemeData theme, String text) => Center(
        child: Text(text,
            style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      );

  String _typeLabel(_TypeFilter t) {
    switch (t) {
      case _TypeFilter.all:
        return 'All';
      case _TypeFilter.pdf:
        return 'PDF';
      case _TypeFilter.images:
        return 'Images';
      case _TypeFilter.docs:
        return 'Docs';
    }
  }

  _openFile(File file) async {
    if (Utility.isPdf(file.path)) {
      GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,
          pathParameters: {'pdfFilePath': file.path});
    } else {
      await OpenFile.open(file.path,
          type: Constants.extrnalOpenSupportedFiles[
                  Utility.fileExtension(file)] ??
              '*/*');
    }
  }

  @override
  void dispose() {
    searchSubject.close();
    bloc.add(const ResetSearchEvent());
    super.dispose();
  }
}
