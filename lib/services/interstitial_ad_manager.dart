import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_helper.dart';

/// Preloads a single interstitial ad and shows it on demand, then reloads
/// the next one in the background so it's ready for the next call.
class InterstitialAdManager {
  InterstitialAdManager._();
  static final InterstitialAdManager instance = InterstitialAdManager._();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  void loadAd() {
    if (_isLoading || _interstitialAd != null) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: AdHelper.request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  /// Shows the preloaded interstitial if one is ready, then calls
  /// [onComplete]. If no ad is ready, calls [onComplete] immediately so the
  /// app flow is never blocked waiting on an ad.
  void showAdThen(VoidCallback onComplete) {
    if (!AdHelper.adsEnabled) {
      onComplete();
      return;
    }
    final ad = _interstitialAd;
    if (ad == null) {
      loadAd();
      onComplete();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadAd();
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadAd();
        onComplete();
      },
    );
    _interstitialAd = null;
    ad.show();
  }
}
