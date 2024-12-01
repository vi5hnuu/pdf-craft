import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/state/files-state/files_bloc.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:rxdart/rxdart.dart';

class MainScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  MainScreen({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final overlayController = OverlayPortalController();
  final BehaviorSubject<String> searchSubject = BehaviorSubject();

  @override
  void initState() {
    searchSubject
        .debounceTime(const Duration(milliseconds: 500))
        .listen((value) {
      if (mounted)
        BlocProvider.of<FilesBloc>(context)
            .add(SearchFile(path: Constants.rootStoragePath, nameLike: value));
    }, cancelOnError: false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final md = MediaQuery.of(context);

    return Scaffold(
      body: BlocConsumer<FilesBloc, FilesState>(
          listener: (context, state) {
            if (state.searchStream == null) {
              overlayController.hide();
            }
            state.searchStream!.listen((data) {
              if (data.isEmpty)
                overlayController.hide();
              else
                overlayController.show();
            });
          },
          listenWhen: (previous, current) =>
              previous.searchStream != current.searchStream,
          buildWhen: (previous, current) =>
              previous.searchStream != current.searchStream,
          builder: (context, state) {
            final screenHeight = md.size.height;
            final appBarHeight =
                Scaffold.of(context).appBarMaxHeight ?? kToolbarHeight;
            final searchStream = state.searchStream;
            return OverlayPortal(
              controller: overlayController,
              overlayChildBuilder: (context) {
                return Positioned(
                  top: appBarHeight,
                  left: 0, // Adjust to position container full-width
                  right: 0, // Ensure it stretches full width
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: 100,
                      maxHeight: screenHeight / 3,
                    ),
                    width: double.infinity,
                    // Full width
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    margin: EdgeInsets.all(12),
                    padding: EdgeInsets.all(8),
                    child: StreamBuilder(
                      stream: searchStream,
                      builder: (context, snapshot) {
                        if (snapshot.data == null) return Text("data");
                        return ListView.builder(itemCount: snapshot.data!.length,itemBuilder: (context, index) {
                          return Text(
                            snapshot.data![index].path,
                            style: TextStyle(color: Colors.black),
                          );
                        },);
                      },
                    ),
                  ),
                );
              },
              child: widget.navigationShell,
            );
          }),
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
        actions: [
          Flexible(
            child: TextFormField(
                onChanged: (value) => searchSubject.sink.add(value)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, left: 16),
            child: CircleAvatar(child: Icon(Icons.person)),
          )
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting,
        elevation: 5,
        iconSize: 24,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
              activeIcon: Icon(Icons.home),
              tooltip: 'Home',
              backgroundColor: Colors.black),
          BottomNavigationBarItem(
              icon: Icon(Icons.folder_copy_outlined),
              label: 'Files',
              activeIcon: Icon(Icons.folder),
              tooltip: 'Files',
              backgroundColor: Colors.black),
          BottomNavigationBarItem(
              icon: Icon(Icons.build_outlined),
              label: 'Tools',
              activeIcon: Icon(Icons.build),
              tooltip: 'Tools',
              backgroundColor: Colors.black),
          BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner_outlined),
              label: 'Scanner',
              activeIcon: Icon(Icons.document_scanner),
              tooltip: 'Scanner',
              backgroundColor: Colors.black),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
              activeIcon: Icon(Icons.settings),
              tooltip: 'Settings',
              backgroundColor: Colors.black),
        ],
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(index,
        initialLocation: index == widget.navigationShell.currentIndex);
  }
}
