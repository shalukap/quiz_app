import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad unit IDs for the app. In debug builds this always returns Google's
/// official test ad unit IDs so local development never serves (or risks
/// invalid clicks on) real ads; release/profile builds use the real IDs.
class AdHelper {
  AdHelper._();

  /// Restricts served ad content and tags every request as child-directed /
  /// under age of consent, for COPPA/GDPR-K compliance. Call once, before
  /// any ad is loaded.
  static Future<void> configure() {
    final requestConfiguration = RequestConfiguration(
      maxAdContentRating: MaxAdContentRating.g,
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
    );
    return MobileAds.instance.updateRequestConfiguration(requestConfiguration);
  }

  /// Ad request used for every banner/interstitial/app-open load. Disables
  /// personalized ads app-wide, consistent with [configure]'s COPPA tagging.
  static const AdRequest request = AdRequest(nonPersonalizedAds: true);

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    return 'ca-app-pub-4939489758437570/2517148394';
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    return 'ca-app-pub-4939489758437570/3777279237';
  }

  static String get appOpenAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/9257395921'
          : 'ca-app-pub-3940256099942544/5575463023';
    }
    return 'ca-app-pub-4939489758437570/5035500523';
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    return 'ca-app-pub-4939489758437570/7054455905';
  }
}
