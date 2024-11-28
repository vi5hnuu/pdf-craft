import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          // the appearance of each tab is defined with a [NavigationDestination] widget
          NavigationDestination(label: 'Section A', icon: Icon(Icons.home)),
          NavigationDestination(label: 'Section B', icon: Icon(Icons.settings)),
        ],
        onDestinationSelected: (index) { /* TODO: move to the tab at index */ },
      ),
      body: SafeArea(child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Text("data")
        ],
      )),
    );
  }
}
