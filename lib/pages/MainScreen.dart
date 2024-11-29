import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting,
        elevation: 5,
        iconSize: 24,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items:const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home',activeIcon: Icon(Icons.home),tooltip: 'Home',backgroundColor: Colors.black),
          BottomNavigationBarItem(icon: Icon(Icons.folder_copy_outlined), label: 'Files',activeIcon: Icon(Icons.settings),tooltip: 'Files',backgroundColor: Colors.black),
          BottomNavigationBarItem(icon: Icon(Icons.build_outlined), label: 'Tools',activeIcon: Icon(Icons.build),tooltip: 'Tools',backgroundColor: Colors.black),
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner_outlined), label: 'Scanner',activeIcon: Icon(Icons.document_scanner),tooltip: 'Scanner',backgroundColor: Colors.black),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings',activeIcon: Icon(Icons.settings),tooltip: 'Settings',backgroundColor: Colors.black),
        ],
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
  void _onTap(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }
}



