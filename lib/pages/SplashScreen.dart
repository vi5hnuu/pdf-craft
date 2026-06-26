import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AppOpenAdManager.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? timer;
  bool _navigated = false; // ensure we navigate exactly once

  @override
  void initState() {
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      ),
    );

    // Navigate as soon as ad init completes — no fixed minimum delay (the
    // splash previously always waited the full timer). MobileAds init is the
    // only gate.
    MobileAds.instance.initialize().then((value) {
      if (!mounted) return;
      // Preload an App Open ad now that MobileAds is initialized, so the first
      // background->foreground (warm resume) has an ad ready to show.
      AppOpenAdManager().loadAd();
      LoggerSingleton().logger.i('Ads ${value.adapterStatuses.keys.join(',')} : ${value.adapterStatuses.values.join(',')}');
      _goOnce();
    });
    // Safety fallback so we never hang if ad init stalls.
    timer=Timer(const Duration(seconds: 3),(){
      if(!mounted) return;
      _goOnce();
    });
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
              margin: const EdgeInsets.symmetric(horizontal: 75, vertical: 100),
              child: LottieBuilder.asset("assets/lottie/files.json",
                  fit: BoxFit.fitWidth, animate: true, backgroundLoading: true),
            ),
            Text(
              'PDF Craft',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            SpinKitPulse(color: theme.primaryColor),
          ],
        ));
  }

  /// Navigates to the next screen exactly once, whichever trigger (ad init or
  /// the safety timer) fires first.
  void _goOnce() {
    if (_navigated) return;
    _navigated = true;
    timer?.cancel();
    goToHome();
  }

  Future<void> goToHome() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    if (!mounted) return;
    if (onboardingDone) {
      GoRouter.of(context).goNamed(AppRoutes.filesRoute.name);
    } else {
      GoRouter.of(context).goNamed(AppRoutes.onboardingRoute.name);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
