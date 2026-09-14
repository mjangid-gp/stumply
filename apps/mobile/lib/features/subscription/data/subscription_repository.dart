import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/constants/app_constants.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

class SubscriptionRepository {
  bool _initialized = false;

  Future<void> initialize(String userId) async {
    if (_initialized) return;
    try {
      await Purchases.configure(
        PurchasesConfiguration('YOUR_REVENUECAT_API_KEY')..appUserID = userId,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('RevenueCat init skipped: $e');
    }
  }

  Future<bool> isProUser() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.all[AppConstants.proEntitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.entitlements.all[AppConstants.proEntitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> restore() async {
    await Purchases.restorePurchases();
  }
}
