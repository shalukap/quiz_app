import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_helper.dart';

/// Preloads a single rewarded ad and shows it on demand, then reloads the
/// next one in the background so it's ready for the next call.
class RewardedAdManager {
  RewardedAdManager._();
  static final RewardedAdManager instance = RewardedAdManager._();

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  bool get isAdReady => _rewardedAd != null;

  void loadAd() {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: AdHelper.request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  /// Shows the preloaded rewarded ad if one is ready. [onUserEarnedReward] is
  /// called only if the user watches the ad to completion. [onAdUnavailable]
  /// is called immediately if no ad is ready (a fresh load is kicked off for
  /// next time), so the caller can tell the user to try again shortly.
  void showAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdUnavailable,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      loadAd();
      onAdUnavailable();
      return;
    }

    bool earnedReward = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadAd();
        if (earnedReward) onUserEarnedReward();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadAd();
        onAdUnavailable();
      },
    );
    _rewardedAd = null;
    ad.show(
      onUserEarnedReward: (ad, reward) => earnedReward = true,
    );
  }
}
