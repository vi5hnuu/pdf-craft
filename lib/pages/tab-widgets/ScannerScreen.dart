import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LottieBuilder.asset("assets/lottie/scanner.json",fit: BoxFit.fitWidth,animate: true,backgroundLoading: true,),
          Text("Comming Soon",style: TextStyle(fontSize: 36,color: Colors.white,fontWeight: FontWeight.w100),)
        ],
      ),
    ));
  }
}
