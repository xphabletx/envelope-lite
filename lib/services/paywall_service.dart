// lib/services/paywall_service.dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/revenue_cat_config.dart';

/// Service to manage subscriptions via RevenueCat
class PaywallService {
  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();

      // Debug: Print all active entitlement keys
      debugPrint('[Paywall] 🔍 Active entitlement keys: ${customerInfo.entitlements.active.keys.toList()}');

      // Check for premium entitlement (checks BOTH IDs)
      final hasEntitlement = RevenueCatConfig.hasPremiumEntitlement(
        customerInfo.entitlements.active,
      );

      debugPrint('[Paywall] Has active subscription: $hasEntitlement');
      return hasEntitlement;
    } catch (e) {
      debugPrint('[Paywall] Error checking subscription: $e');
      return false;
    }
  }

  /// Get available subscription offerings
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();

      if (offerings.current == null) {
        debugPrint('[Paywall] No offerings available');
        return null;
      }

      debugPrint('[Paywall] Found ${offerings.current!.availablePackages.length} packages');
      return offerings;
    } catch (e) {
      debugPrint('[Paywall] Error fetching offerings: $e');
      return null;
    }
  }

  /// Purchase a package
  Future<bool> purchase(Package package, BuildContext context) async {
    try {
      final purchaseResult = await Purchases.purchase(PurchaseParams.package(package));

      // Debug: Print all active entitlement keys
      debugPrint('[Paywall] 🔍 Active entitlement keys after purchase: ${purchaseResult.customerInfo.entitlements.active.keys.toList()}');

      // Check for premium entitlement (checks BOTH IDs)
      final hasEntitlement = RevenueCatConfig.hasPremiumEntitlement(
        purchaseResult.customerInfo.entitlements.active,
      );

      if (hasEntitlement) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to Premium! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } else {
        return false;
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[Paywall] User cancelled purchase');
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase not allowed. Check parental controls.')),
          );
        }
      } else {
        debugPrint('[Paywall] Purchase error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase failed. Please try again.')),
          );
        }
      }

      return false;
    } catch (e) {
      debugPrint('[Paywall] Unexpected purchase error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase failed. Please try again.')),
        );
      }
      return false;
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases(BuildContext context) async {
    try {
      final customerInfo = await Purchases.restorePurchases();

      // Debug: Print all active entitlement keys
      debugPrint('[Paywall] 🔍 Active entitlement keys after restore: ${customerInfo.entitlements.active.keys.toList()}');

      // Check for premium entitlement (checks BOTH IDs)
      final hasEntitlement = RevenueCatConfig.hasPremiumEntitlement(
        customerInfo.entitlements.active,
      );

      if (hasEntitlement) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription restored! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No previous purchases found')),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('[Paywall] Restore error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to restore purchases')),
        );
      }
      return false;
    }
  }

  /// Link anonymous user to RevenueCat on account creation
  Future<void> identifyUser(String userId) async {
    try {
      await Purchases.logIn(userId);
      debugPrint('[Paywall] User identified: $userId');
    } catch (e) {
      debugPrint('[Paywall] Error identifying user: $e');
    }
  }

  /// Log out user from RevenueCat
  /// Prevents 'Called logOut but current user is anonymous' error
  Future<void> logOut() async {
    try {
      // Check if user is anonymous before logging out
      final isAnonymous = await Purchases.isAnonymous;
      if (!isAnonymous) {
        await Purchases.logOut();
        debugPrint('[Paywall] User logged out from RevenueCat');
      } else {
        debugPrint('[Paywall] User is anonymous, skipping RevenueCat logout');
      }
    } catch (e) {
      debugPrint('[Paywall] Error logging out: $e');
    }
  }
}
