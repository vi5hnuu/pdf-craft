import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? timer;

  @override
  void initState() {
    timer=Timer(const Duration(seconds: 5),()=>goToHome());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context);

    return Scaffold(
        body: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 75,vertical: 125),
              child:LottieBuilder.asset("assets/lottie/files.json",fit: BoxFit.fitWidth,animate: true,backgroundLoading: true,),
            ),
            Column(
              children: [
                Text(
                  "Pdf Craft",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: "PermanentMarker", fontSize: 32, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 15),
                SpinKitPulse(color: theme.primaryColor)
              ],
            ),
          ],
        ));
  }

  goToHome(){
    GoRouter.of(context).replaceNamed('home');
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
