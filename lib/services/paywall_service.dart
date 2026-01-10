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

      // Check for premium entitlement (checks BOTH IDs)
      final hasEntitlement = RevenueCatConfig.hasPremiumEntitlement(
        customerInfo.entitlements.active,
      );

      return hasEntitlement;
    } catch (e) {
      return false;
    }
  }

  /// Get available subscription offerings
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();

      if (offerings.current == null) {
        return null;
      }

      return offerings;
    } catch (e) {
      return null;
    }
  }

  /// Purchase a package
  Future<bool> purchase(Package package, BuildContext context) async {
    try {
      final purchaseResult = await Purchases.purchase(PurchaseParams.package(package));

      // Debug: Print all active entitlement keys

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
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase not allowed. Check parental controls.')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase failed. Please try again.')),
          );
        }
      }

      return false;
    } catch (e) {
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
    } catch (e) {
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
      } else {
      }
    } catch (e) {
    }
  }
}
