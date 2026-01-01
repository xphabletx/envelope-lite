// lib/services/subscription_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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
      debugPrint('[SubscriptionService] Already initialized, skipping');
      return;
    }

    try {
      // Set log level based on build mode
      // Production: Only show errors to keep logs clean
      // Debug: Show all logs for troubleshooting
      if (kReleaseMode) {
        await Purchases.setLogLevel(LogLevel.error);
        debugPrint('[SubscriptionService] Log level set to ERROR (production)');
      } else {
        await Purchases.setLogLevel(LogLevel.debug);
        debugPrint('[SubscriptionService] Log level set to DEBUG (development)');
      }

      // Configure platform-specific API keys
      PurchasesConfiguration? configuration;

      // Use test key in debug mode, production keys in release mode
      if (kReleaseMode) {
        // Production mode - use platform-specific production keys
        if (Platform.isIOS || Platform.isMacOS) {
          configuration = PurchasesConfiguration(RevenueCatConfig.iosApiKey);
          debugPrint('[SubscriptionService] Using iOS production API key');
        } else if (Platform.isAndroid) {
          configuration = PurchasesConfiguration(RevenueCatConfig.androidApiKey);
          debugPrint('[SubscriptionService] Using Android production API key');
        } else {
          debugPrint('[SubscriptionService] Platform not supported, skipping initialization');
          return; // Web/Desktop not supported
        }
      } else {
        // Debug/development mode - use test key for all platforms
        if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
          configuration = PurchasesConfiguration(RevenueCatConfig.testApiKey);
          debugPrint('[SubscriptionService] Using test API key (debug mode)');
        } else {
          debugPrint('[SubscriptionService] Platform not supported, skipping initialization');
          return; // Web/Desktop not supported
        }
      }

      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint('[SubscriptionService] ✅ Initialized successfully');
    } catch (e) {
      debugPrint('[SubscriptionService] ❌ Initialization failed: $e');
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
        debugPrint('[SubscriptionService] 🔓 VIP Bypass Active for $userEmail');
        debugPrint('[SubscriptionService] ⚠️ REMINDER: Remove VIP bypass before production release!');
        return true;
      }

      // Check RevenueCat entitlement
      final customerInfo = await Purchases.getCustomerInfo();
      final hasPremium = customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.premiumEntitlementId);

      debugPrint('[SubscriptionService] Has active subscription: $hasPremium');
      return hasPremium;
    } catch (e) {
      debugPrint('[SubscriptionService] Error checking subscription: $e');
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
        debugPrint('[SubscriptionService] ✅ Authorization granted for $userEmail (VIP)');
        debugPrint('[SubscriptionService] ⚠️ REMINDER: Remove VIP bypass before production release!');
        return SyncAuthResult(
          authorized: true,
          reason: 'VIP user',
          userEmail: userEmail,
        );
      }

      // Check RevenueCat entitlement
      final customerInfo = await Purchases.getCustomerInfo();
      final hasPremium = customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.premiumEntitlementId);

      if (hasPremium) {
        debugPrint('[SubscriptionService] ✅ Authorization granted for $userEmail (Premium)');
        return SyncAuthResult(
          authorized: true,
          reason: 'Stuffrite Premium subscriber',
          userEmail: userEmail,
        );
      }

      // No valid subscription or VIP status
      debugPrint('[SubscriptionService] ⛔ Authorization denied for $userEmail (no premium)');
      return SyncAuthResult(
        authorized: false,
        reason: 'No active subscription',
        userEmail: userEmail,
      );
    } catch (e) {
      debugPrint('[SubscriptionService] ❌ Error checking sync authorization: $e');
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
      debugPrint('[SubscriptionService] Error fetching customer info: $e');
      return null;
    }
  }

  /// Identify user in RevenueCat for purchase attribution
  ///
  /// Should be called after user signs in
  Future<void> identifyUser(String userId) async {
    try {
      await Purchases.logIn(userId);
      debugPrint('[SubscriptionService] User identified: $userId');
    } catch (e) {
      debugPrint('[SubscriptionService] Error identifying user: $e');
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
        debugPrint('[SubscriptionService] User logged out from RevenueCat');
      } else {
        debugPrint('[SubscriptionService] User is anonymous, skipping RevenueCat logout');
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Error logging out: $e');
    }
  }

  /// Check if SDK is initialized
  bool get isInitialized => _isInitialized;
}
