import 'package:flutter/foundation.dart';

import 'grades.dart';

/// Settings for "QuizMaster Premium" (RevenueCat + Google Play / App Store subscriptions).
///
/// Setup (see PREMIUM_SETUP.md in the project root for the full checklist):
///  * Google Play: one subscription per grade, product id `premium_grade_<n>`,
///    with base plans `monthly` (99 LKR), `quarterly` (270 LKR), `yearly` (999 LKR).
///  * App Store: one subscription group per grade with products
///    `premium_grade_<n>_monthly`, `premium_grade_<n>_quarterly`, `premium_grade_<n>_yearly`.
///  * RevenueCat: entitlement `grade_<n>` and offering `grade_<n>` per grade,
///    each offering containing the Monthly, Three Month and Annual packages.
///  * EB exams (grade 101–103, see grades.dart) are a one-time purchase instead:
///    Google Play in-app product `premium_eb_<n>` (199 LKR), attached to
///    entitlement `grade_10<n>` and offered as the Lifetime package of offering `grade_10<n>`.
class PremiumConfig {
  PremiumConfig._();

  /// RevenueCat *public* Google Play SDK key (starts with `goog_`).
  /// Find it in RevenueCat → Project settings → API keys.
  /// Can also be supplied at build time:
  ///   flutter build appbundle --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
  /// While empty, Premium is disabled and the app behaves like the free version.
  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY', defaultValue: 'goog_SGgOloclXdFfvPZcvPgiPXFtYZi');

  /// RevenueCat *public* App Store SDK key (starts with `appl_`).
  /// Can also be supplied at build time:
  ///   flutter build ipa --dart-define=REVENUECAT_IOS_KEY=appl_xxx
  /// While empty, Premium is disabled on iOS.
  static const String revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY', defaultValue: '');

  /// Key for the current platform, or empty if Premium isn't supported here.
  static String get revenueCatKey {
    if (kIsWeb) return '';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => revenueCatAndroidKey,
      TargetPlatform.iOS => revenueCatIosKey,
      _ => '',
    };
  }

  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Store name shown in purchase-related messages.
  static String get storeName => isIOS ? 'the App Store' : 'Google Play';

  static String get manageSubscriptionsUrl => isIOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';

  static String get cancelInstructions => isIOS
      ? 'You can cancel anytime in Settings → your name → Subscriptions.'
      : 'You can cancel anytime in Google Play → Payments & subscriptions → Subscriptions.';

  /// Required by App Store guideline 3.1.2 on the paywall.
  static const String termsUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  // TODO: replace with the URL where PRIVACY_POLICY.md is hosted.
  static const String privacyPolicyUrl = 'https://quizmaster-app.web.app/privacy';

  static const String displayName = 'QuizMaster Premium';

  /// Sets with index below this are never premium-locked
  /// (index 0 is free, index 1 unlocks with a rewarded ad).
  static const int freeSetsPerSubject = 2;

  static String entitlementId(int grade) => 'grade_$grade';
  static String offeringId(int grade) => 'grade_$grade';

  static int? gradeFromEntitlement(String id) =>
      id.startsWith('grade_') ? int.tryParse(id.substring(6)) : null;

  /// Shown only if the store prices can't be loaded (e.g. offline).
  static const fallbackPrices = {
    PremiumPlan.monthly: 'LKR 99',
    PremiumPlan.quarterly: 'LKR 270',
    PremiumPlan.yearly: 'LKR 999',
    PremiumPlan.lifetime: 'LKR 199',
  };

  /// Plans offered for a grade, best value first.
  static List<PremiumPlan> plansFor(int? grade) => grade != null && Grades.isEbExam(grade)
      ? const [PremiumPlan.lifetime]
      : const [PremiumPlan.yearly, PremiumPlan.quarterly, PremiumPlan.monthly];
}

enum PremiumPlan {
  monthly('Monthly', '/ month', null),
  quarterly('3 months', '/ 3 months', 'Save 9%'),
  yearly('Yearly', '/ year', 'Save 16%'),
  lifetime('Lifetime access', 'one-time', null);

  bool get isOneTime => this == lifetime;

  final String label;
  final String period;
  final String? saving;
  const PremiumPlan(this.label, this.period, this.saving);
}
