import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/singletons/pro_service.dart';
import 'package:pdf_craft/utils/ad_units.dart';

class BannerAdd extends StatefulWidget {
  const BannerAdd({super.key});

  @override
  State<BannerAdd> createState() => _BannerAddState();
}

class _BannerAddState extends State<BannerAdd> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    _loadAd();
    super.initState();
  }

  @override
  void dispose() {
    // There was no dispose at all, so every banner leaked its native ad object: the Flutter
    // widget went away and the AdMob instance behind it stayed alive for the life of the
    // process. Six screens made that a slow drip; putting banners inside the tool flows would
    // have multiplied it across twenty more.
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ProService().isPro) return const SizedBox.shrink(); // no ads for Pro
    if(_bannerAd==null ) return const SizedBox.shrink();
    return SizedBox(height: AdSize.banner.height.toDouble(),child: AdWidget(ad: _bannerAd!));
  }

  void _loadAd() {
    if (ProService().isPro) return; // don't request ads for Pro users
    final bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AdUnits.banner,
      // Keywords describe *this* app's audience. They used to be coding-site terms — gfg,
      // leetcode, codechef, naukri — which asked AdMob to fill a PDF utility's inventory with
      // ads aimed at people practising algorithms. Wrong audience means a worse match and a
      // lower eCPM, so this is a revenue fix as much as a relevance one.
      request: const AdRequest(keywords: [
        'pdf', 'pdf editor', 'document scanner', 'e-sign', 'office',
        'file manager', 'cloud storage', 'printing', 'productivity',
      ]),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (ad, error) {
          LoggerSingleton().logger.e('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );

    // Start loading.
    bannerAd.load();
  }
}