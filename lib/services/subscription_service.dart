import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/premium_config.dart';
import '../state/app_state.dart';

enum PurchaseOutcome { success, cancelled, pending, error }

/// Wraps RevenueCat. Exposes which grades the signed-in user has Premium for
/// and notifies listeners whenever that changes (purchase, renewal, expiry,
/// account switch).
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  bool _configured = false;
  CustomerInfo? _customerInfo;
  Set<int> _activeGrades = {};

  /// False on web, or when no RevenueCat key is configured.
  bool get isAvailable => _configured;

  /// True if the user has Premium for at least one grade. Used for the
  /// ad-free experience and the premium look.
  bool get isPremium => _activeGrades.isNotEmpty;

  Set<int> get activeGrades => Set.unmodifiable(_activeGrades);

  bool hasGrade(int grade) => _activeGrades.contains(grade);

  String? get managementUrl => _customerInfo?.managementURL;

  EntitlementInfo? entitlementFor(int grade) =>
      _customerInfo?.entitlements.active[PremiumConfig.entitlementId(grade)];

  Future<void> init() async {
    final key = PremiumConfig.revenueCatKey;
    if (key.isEmpty) {
      debugPrint('Premium disabled: RevenueCat not configured for this platform.');
      return;
    }
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      final config = PurchasesConfiguration(key)..appUserID = AppState.currentUid;
      await Purchases.configure(config);
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('RevenueCat init failed: $e');
    }
  }

  /// Links purchases to the Firebase user so Premium follows them across devices.
  Future<void> identify(String uid) async {
    if (!_configured) return;
    try {
      final result = await Purchases.logIn(uid);
      _apply(result.customerInfo);
    } catch (e) {
      debugPrint('RevenueCat logIn failed: $e');
    }
  }

  Future<void> signOut() async {
    if (!_configured) return;
    try {
      if (!await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
    } catch (e) {
      debugPrint('RevenueCat logOut failed: $e');
    }
    _customerInfo = null;
    _setGrades({});
  }

  Future<Offering?> offeringForGrade(int grade) async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.getOffering(PremiumConfig.offeringId(grade));
    } catch (e) {
      debugPrint('Failed to load offerings: $e');
      return null;
    }
  }

  static Package? packageFor(Offering? offering, PremiumPlan plan) => switch (plan) {
        PremiumPlan.monthly => offering?.monthly,
        PremiumPlan.quarterly => offering?.threeMonth,
        PremiumPlan.yearly => offering?.annual,
        PremiumPlan.lifetime => offering?.lifetime,
      };

  Future<(PurchaseOutcome, String?)> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _apply(result.customerInfo);
      return (PurchaseOutcome.success, null);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return (PurchaseOutcome.cancelled, null);
      }
      if (code == PurchasesErrorCode.paymentPendingError) {
        return (PurchaseOutcome.pending, null);
      }
      return (PurchaseOutcome.error, e.message);
    }
  }

  /// Returns true if any Premium grade was restored.
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      _apply(await Purchases.restorePurchases());
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
    return isPremium;
  }

  void _apply(CustomerInfo info) {
    _customerInfo = info;
    _setGrades(info.entitlements.active.keys
        .map(PremiumConfig.gradeFromEntitlement)
        .whereType<int>()
        .toSet());
  }

  void _setGrades(Set<int> grades) {
    _activeGrades = grades;
    notifyListeners();
  }
}
