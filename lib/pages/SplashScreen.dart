import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AppOpenAdManager.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';
import 'package:pdf_craft/singletons/RewardedAdManager.dart';
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
      // Preload a rewarded ad for the first heavy-tool gate.
      RewardedAdManager().loadAd();
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo on a soft rounded card — lightweight, no animation file.
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Image.asset('assets/logo.webp', fit: BoxFit.contain),
              ),
              const SizedBox(height: 24),
              Text(
                'PDF Craft',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your complete PDF toolkit',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 36),
              SpinKitThreeBounce(color: primary, size: 22),
            ],
          ),
        ),
      ),
    );
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
