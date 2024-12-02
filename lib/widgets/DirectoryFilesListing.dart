import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/utils/httpStates.dart';
import 'package:pdf_craft/utils/utility.dart';
import 'package:url_launcher/url_launcher.dart';


class DirectoryFilesListing extends StatefulWidget {
  final String directoryPath;
  final bool? multiSelect;//on null no selection allow
  final List<String> limitSelectionToExtensions;
  final int? minSelection;
  final Function(List<File>)? onDoneSelection;

  DirectoryFilesListing({super.key, required this.directoryPath,this.multiSelect,this.limitSelectionToExtensions=const [],this.onDoneSelection,this.minSelection}){
    if(multiSelect==null && (onDoneSelection!=null || minSelection!=null)) throw Exception("multiSelect is disabled but onDownSelection/minSelection is not null");
    if(multiSelect!=null && onDoneSelection==null) throw Exception("OnDoneSelection is required");
  }

  @override
  State<DirectoryFilesListing> createState() => _DirectoryFilesListingState();
}

class _DirectoryFilesListingState extends State<DirectoryFilesListing> {
  late final FilesBloc bloc;
  final List<File> selectedFiles=[];
  List<String> pathToDirectory = [];

  @override
  void initState() {
    bloc=BlocProvider.of<FilesBloc>(context);
    pathToDirectory = [widget.directoryPath];
    _loadDirectoryFiles(pathToDirectory.last);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final router=GoRouter.of(context);

    return Scaffold(
        body: SafeArea(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (pathToDirectory.length <= 1) {
            router.pop();
          } else {
            setState(() {
              pathToDirectory.removeLast();
              _loadDirectoryFiles(pathToDirectory.last);
            });
          }
        },
        child:  BlocConsumer<FilesBloc,FilesState>(listener: (context, state) {
          final error=state.getError(forr: HttpStates.LOAD_DIRECTORY_FILES);
          if(error!=null){
            NotificationService.showSnackbar(text: error,color: Colors.red);
            setState(()=>pathToDirectory.removeLast());
            if(pathToDirectory.isEmpty) router.pop();
          }
        },
          buildWhen: (previous, current) => previous!=current,
          listenWhen: (previous, current) => previous!=current,
          builder: (context, state) {
          return Stack(children: [
            if(!state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES))(state.files.isEmpty
                ? const Center(child: Text('No files found'))
                : Column(mainAxisSize: MainAxisSize.max,
                  children: [
                Expanded(child: ListView.builder(
                    itemCount: state.files.length,
                    itemBuilder: (context, index) {
                      final file = state.files[index];
                      return ListTile(
                        enabled: file is Directory || widget.limitSelectionToExtensions.isEmpty || widget.limitSelectionToExtensions.contains(Utility.fileExtension(file as File)),
                        selected: _isFileSelected(file),
                        selectedTileColor: Colors.green.withOpacity(0.15),
                        selectedColor: Colors.green,
                        leading: file is Directory
                            ? const Icon(FontAwesomeIcons.solidFolder,
                            color: Colors.yellowAccent)
                            : const Icon(FontAwesomeIcons.file,
                            color: Colors.orange),
                        title: Text(file.path.split('/').last),
                        subtitle: (file is! Directory) ? Text(Utility.bytesToSize(File(file.path).lengthSync())) : null,
                        onTap:()=> _onItemClick(file: file)
                      );
                    })),
                                AnimatedOpacity(opacity:selectedFiles.isNotEmpty ? 1 : 0, duration: Duration(milliseconds: 300),child: selectedFiles.isNotEmpty ? Container(
                                  padding: const EdgeInsets.all(16),
                                  width: double.infinity,
                                  decoration: BoxDecoration(color: Colors.black87),
                                  child: FilledButton(onPressed:widget.onDoneSelection==null || (widget.minSelection!=null && selectedFiles.length<widget.minSelection!) ? null : ()=>widget.onDoneSelection!(selectedFiles),
                                      child: Text("Complete Selection")),
                                ):null)
                              ],
                            )),
            if (state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES))
              Expanded(
                  child: Container(
                    decoration:BoxDecoration(color: Colors.black.withOpacity(0.8)),
                    child: const Align(alignment: Alignment.center, child: SpinKitRipple(size: 72, color: Colors.green)),
                  )),
          ]);
        },),
      ),
    ));
  }

  bool _isFileSelected(FileSystemEntity file){
    if(file is Directory) return false;
    try{
      return selectedFiles.firstWhere((selectedFile)=>selectedFile.path==file.path)!=null;
    }catch(e){
     return false;
    }
  }

  _loadDirectoryFiles(String path){
    if(bloc.state.isLoading(forr: HttpStates.LOAD_DIRECTORY_FILES)) return;
    bloc.add(LoadDirectoryFiles(path: pathToDirectory.last));
  }


  @override
  void dispose() {
    super.dispose();
  }

  _onItemClick({required FileSystemEntity file}) async {
    try{
      if(file is Directory){
        _loadDirectoryFiles((pathToDirectory..add(file.path)).last);
        return;
      }

      if(widget.multiSelect==null){//allow opening file only
        if(Utility.isPdf(file.path)) {
          GoRouter.of(context).pushNamed(AppRoutes.pdfFilePreviewRoute.name,pathParameters: {'pdfFilePath':file.path});
        } else {
          OpenFile.open(file.path,type: Constants.extrnalOpenSupportedFiles[Utility.fileExtension(file as File)] ?? '*/*');
        }
      }else{
        if(widget.multiSelect==true || selectedFiles.isEmpty){
          setState((){
            if(_isFileSelected(file)) selectedFiles.removeWhere((selectedFile)=>selectedFile.path==file.path);
            else selectedFiles.add(file as File);
          });
        }else{
          NotificationService.showSnackbar(text: "Multiple file selection not allowed");
        }
      }
    }catch(e){
      NotificationService.showSnackbar(text: "Something went wrong",color: Colors.red,showCloseIcon: true);
    }
  }
}
