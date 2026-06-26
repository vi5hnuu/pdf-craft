import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_craft/singletons/LoggerSingleton.dart';

/// Manages the lifecycle of a single App Open ad.
///
/// An App Open ad is the full-screen ad shown when the user *returns* to the
/// app from the background (warm resume). This manager only loads/caches/shows
/// the ad — deciding *when* to show it (warm resume only) is the caller's job
/// (see the lifecycle observer in main.dart). This keeps the class focused on a
/// single responsibility.
class AppOpenAdManager {
  /// Real production App Open ad unit id.
  static const String _adUnitId = 'ca-app-pub-4715945578201106/5084422823';

  /// App Open ads are only valid for ~4 hours after load (Google guidance);
  /// showing a staler ad is wasteful, so we discard and reload past this.
  static const Duration _maxCacheAge = Duration(hours: 4);

  AppOpenAd? _cachedAd;
  DateTime? _loadedAt;
  bool _isLoading = false;
  bool _isShowingAd = false;

  static final AppOpenAdManager _instance = AppOpenAdManager._();

  AppOpenAdManager._();

  factory AppOpenAdManager() => _instance;

  /// True when a non-expired ad is cached and ready to show.
  bool get _isAdAvailable =>
      _cachedAd != null &&
      _loadedAt != null &&
      DateTime.now().difference(_loadedAt!) < _maxCacheAge;

  /// Loads an App Open ad and caches it — does NOT show it.
  /// Safe to call repeatedly; it no-ops while a load is in flight or a fresh
  /// ad is already cached. Requires MobileAds to be initialized first.
  void loadAd() {
    if (_isLoading || _isAdAvailable) return;
    _isLoading = true;
    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(keywords: [
        'pdf', 'file management', 'ilovepdf', 'document', 'compress',
        'merge', 'split', 'convert', 'scanner'
      ]),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _cachedAd = ad;
          _loadedAt = DateTime.now();
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          LoggerSingleton().logger.e('App open ad failed to load: $error');
        },
      ),
    );
  }

  /// Shows the cached ad if one is fresh and nothing else is showing,
  /// then preloads the next one. If no ad is ready, it kicks off a load so the
  /// next resume has one available.
  void showAdIfAvailable() {
    if (_isShowingAd) return;
    if (!_isAdAvailable) {
      loadAd();
      return;
    }

    final ad = _cachedAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAd = true,
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _clearCache();
        loadAd(); // preload next ad after dismiss
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _clearCache();
        LoggerSingleton().logger.e('App open ad failed to show: $error');
        loadAd();
      },
    );
    ad.show();
  }

  void _clearCache() {
    _cachedAd = null;
    _loadedAt = null;
  }
}
