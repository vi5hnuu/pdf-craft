import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:pdf_craft/widgets/FileTile.dart';
import 'package:rxdart/rxdart.dart';

class SearchScreen extends StatefulWidget {

  SearchScreen({
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late FilesBloc bloc=BlocProvider.of<FilesBloc>(context);
  final BehaviorSubject<String> searchSubject = BehaviorSubject();

  @override
  void initState() {
    searchSubject
        .debounceTime(const Duration(milliseconds: 500))
        .listen((value) {
      if (!mounted) return;
      if(!value.isEmpty) bloc.add(SearchFile(path: Constants.rootStoragePath, nameLike: value));
      else bloc.add(const ResetSearch());
      }, cancelOnError: false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

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
        backgroundColor: Colors.black,
        leadingWidth: 112,
        bottom: PreferredSize(preferredSize: const Size(double.infinity,  60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextFormField(onChanged: (value) => searchSubject.sink.add(value)),
            )),
      ),
      body: BlocBuilder<FilesBloc, FilesState>(
          buildWhen: (previous, current) => previous.searchStream != current.searchStream,
          builder: (context, state) {
            final searchStream = state.searchStream;
            return searchStream==null ? Text("Try seaching something",style: TextStyle(color: Colors.white)) :
            StreamBuilder(stream: searchStream, builder: (context, snapshot) {
              return ListView.builder(itemCount: snapshot.data?.length ?? 0,itemBuilder: (context, index) {
                final File file=snapshot.data![index];
                return FileTile(file: file,onPress: () => _openFile(file));
              },);
            },);
          }),

    );
  }

  _openFile(File file) async {
    if(Utility.isPdf(file.path)) GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':file.path});
    else await OpenFile.open(file.path,type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(file)] ?? '*/*');
  }

  @override
  void dispose() {
    bloc.add(const ResetSearch());
    super.dispose();
  }
}
