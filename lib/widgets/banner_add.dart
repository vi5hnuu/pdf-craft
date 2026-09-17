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
      request: const AdRequest(keywords: ['gfg','geeksforgeeks','leetcode','codingninja','codechef','codeforces','naukri','pdf','ilovepdf','file management']),
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