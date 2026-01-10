// lib/services/subscription_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../config/revenue_cat_config.dart';

/// Result of sync authorization check
class SyncAuthResult {
  final bool authorized;
  final String reason;
  final String? userEmail;

  SyncAuthResult({
    required this.authorized,
    required this.reason,
    this.userEmail,
  });
}

/// Service to manage RevenueCat subscription initialization and checks
///
/// Singleton service that handles:
/// - RevenueCat SDK initialization
/// - Subscription status checks
/// - VIP user bypass logic
/// - User identification for purchase attribution
class SubscriptionService {
  // Singleton pattern
  SubscriptionService._();
  static final SubscriptionService _instance = SubscriptionService._();
  factory SubscriptionService() => _instance;

  bool _isInitialized = false;

  /// Initialize RevenueCat SDK
  ///
  /// Should be called once during app startup (in main.dart)
  /// Sets up the SDK with platform-specific API keys and configures logging
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      // Set log level based on build mode
      // Production: Only show errors to keep logs clean
      // Debug: Show all logs for troubleshooting
      if (kReleaseMode) {
        await Purchases.setLogLevel(LogLevel.error);
      } else {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      // Configure platform-specific API keys
      PurchasesConfiguration? configuration;

      // Use test key in debug mode, production keys in release mode
      if (kReleaseMode) {
        // Production mode - use platform-specific production keys
        if (Platform.isIOS || Platform.isMacOS) {
          configuration = PurchasesConfiguration(RevenueCatConfig.iosApiKey);
        } else if (Platform.isAndroid) {
          configuration = PurchasesConfiguration(RevenueCatConfig.androidApiKey);
        } else {
          return; // Web/Desktop not supported
        }
      } else {
        // Debug/development mode - use test key for all platforms
        if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
          configuration = PurchasesConfiguration(RevenueCatConfig.testApiKey);
        } else {
          return; // Web/Desktop not supported
        }
      }

      await Purchases.configure(configuration);
      _isInitialized = true;
    } catch (e) {
      // Don't rethrow - allow app to continue even if RevenueCat fails
    }
  }

  /// Check if user has active premium subscription
  ///
  /// Returns true if:
  /// - User is a VIP (dev bypass)
  /// - User has active "Stuffrite Premium" entitlement
  ///
  /// [userEmail] - Optional email to check for VIP status
  Future<bool> hasActiveSubscription({String? userEmail}) async {
    try {
      // VIP bypass check
      if (RevenueCatConfig.isVipUser(userEmail)) {
        return true;
      }

      // Check RevenueCat entitlement
      final customerInfo = await Purchases.getCustomerInfo();

      // Debug: Print all active and ALL entitlement keys

      // Check for premium entitlement
      final hasPremium = RevenueCatConfig.hasPremiumEntitlement(
        customerInfo.entitlements.active,
      );

      return hasPremium;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can sync data to Firebase (centralized authorization)
  ///
  /// This is the SINGLE SOURCE OF TRUTH for sync authorization.
  /// Used by SyncManager and CloudMigrationService.
  ///
  /// Returns true if:
  /// - User is a VIP (dev bypass via email check)
  /// - User has active "Stuffrite Premium" entitlement from RevenueCat
  ///
  /// [userEmail] - Optional email to check for VIP status
  ///
  /// Returns [SyncAuthResult] containing authorization status and reason
  Future<SyncAuthResult> canSync({String? userEmail}) async {
    try {
      // VIP bypass check (dev/testing)
      if (RevenueCatConfig.isVipUser(userEmail)) {
        return SyncAuthResult(
          authorized: true,
          reason: 'VIP user',
          userEmail: userEmail,
        );
      }

      // Check RevenueCat entitlement
      final customerInfo = await Purchases.getCustomerInfo();

      // Debug: Print all active and ALL entitlement keys

      // Check for premium entitlement
      final hasPremium = RevenueCatConfig.hasPremiumEntitlement(
        customerInfo.entitlements.active,
      );

      if (hasPremium) {
        return SyncAuthResult(
          authorized: true,
          reason: 'Stuffrite Premium subscriber',
          userEmail: userEmail,
        );
      }

      // No valid subscription or VIP status
      return SyncAuthResult(
        authorized: false,
        reason: 'No active subscription',
        userEmail: userEmail,
      );
    } catch (e) {
      return SyncAuthResult(
        authorized: false,
        reason: 'Error checking subscription: $e',
        userEmail: userEmail,
      );
    }
  }

  /// Get customer info from RevenueCat
  ///
  /// Returns null if there's an error fetching customer info
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      return null;
    }
  }

  /// Identify user in RevenueCat for purchase attribution
  ///
  /// Should be called after user signs in
  Future<void> identifyUser(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (e) {
    }
  }

  /// Log out user from RevenueCat
  ///
  /// Should be called when user signs out
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

  /// Check if SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Present RevenueCat Customer Center
  ///
  /// This shows a native UI for managing subscriptions, including:
  /// - Viewing subscription status
  /// - Managing subscriptions
  /// - Restoring purchases
  /// - Accessing support
  ///
  /// Returns true if successfully presented, false otherwise
  Future<bool> presentCustomerCenter(BuildContext context) async {
    try {

      await RevenueCatUI.presentCustomerCenter();

      return true;
    } on PlatformException catch (e) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open subscription management: ${e.message}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    } catch (e) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open subscription management'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}
