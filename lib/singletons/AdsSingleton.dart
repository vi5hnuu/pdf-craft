import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';

abstract class AdEvent {}

/// Preload an interstitial ad (call in tool view initState)
class LoadInterstitialAd extends AdEvent {}

/// Show the preloaded ad — call only on successful tool completion
class ShowInterstitialAd extends AdEvent {}

class AdsSingleton {
  final StreamController<AdEvent> _events;
  InterstitialAd? _cachedAd;
  bool _isLoading = false;

  static final AdsSingleton _instance = AdsSingleton._();

  AdsSingleton._() : _events = StreamController<AdEvent>() {
    _events.stream.listen((event) {
      if (event is LoadInterstitialAd) _preload();
      if (event is ShowInterstitialAd) _show();
    });
    _preload(); // preload on startup so first tool open is ready
  }

  factory AdsSingleton() => _instance;

  /// Loads an ad and stores it — does NOT show immediately.
  void _preload() {
    if (_isLoading || _cachedAd != null) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-4715945578201106/9362646476',
      request: const AdRequest(keywords: [
        'pdf', 'file management', 'ilovepdf', 'document', 'compress',
        'merge', 'split', 'convert', 'scanner'
      ]),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _cachedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          LoggerSingleton().logger.e('Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Shows the cached ad (if ready), then preloads the next one.
  void _show() {
    if (_cachedAd == null) {
      _preload(); // try again for next time
      return;
    }
    _cachedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _cachedAd = null;
        _preload(); // preload next ad after dismiss
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _cachedAd = null;
        _preload();
      },
    );
    _cachedAd!.show();
  }

  void dispatch(AdEvent event) => _events.sink.add(event);
}
