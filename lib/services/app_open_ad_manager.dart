import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_helper.dart';

/// Loads an App Open ad and shows it whenever the app returns to the
/// foreground. Google discards app open ads after 4 hours, so a stale ad is
/// never shown.
class AppOpenAdManager {
  AppOpenAdManager._();
  static final AppOpenAdManager instance = AppOpenAdManager._();

  static const Duration _maxCacheDuration = Duration(hours: 4);

  AppOpenAd? _appOpenAd;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  DateTime? _loadTime;

  /// Set to true right before opening the system image picker (or any other
  /// flow that briefly backgrounds the app) so the resulting resume event
  /// doesn't trigger an ad on top of it.
  bool suppressNextShow = false;

  bool get _isAdAvailable {
    final ad = _appOpenAd;
    final loadTime = _loadTime;
    if (ad == null || loadTime == null) return false;
    return DateTime.now().difference(loadTime) < _maxCacheDuration;
  }

  void loadAd() {
    if (_isLoadingAd || _isAdAvailable) return;
    _isLoadingAd = true;
    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: AdHelper.request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isLoadingAd = false;
          _loadTime = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _isLoadingAd = false;
          debugPrint('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  void showAdIfAvailable() {
    if (!AdHelper.adsEnabled) return;
    if (suppressNextShow) {
      suppressNextShow = false;
      return;
    }
    if (_isShowingAd || !_isAdAvailable) {
      loadAd();
      return;
    }

    final ad = _appOpenAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAd = true,
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
    );
    ad.show();
  }
}

/// Shows an App Open ad each time the app resumes from the background.
class AppOpenLifecycleReactor with WidgetsBindingObserver {
  void listen() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppOpenAdManager.instance.showAdIfAvailable();
    }
  }
}
