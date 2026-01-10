// lib/config/revenue_cat_config.dart

/// RevenueCat configuration for Stuffrite (com.stuffrite.app)
///
/// SECURITY: API keys are now loaded from environment variables.
/// Set these before running:
/// - REVENUECAT_TEST_API_KEY
/// - REVENUECAT_IOS_API_KEY
/// - REVENUECAT_ANDROID_API_KEY
class RevenueCatConfig {
  RevenueCatConfig._(); // Private constructor to prevent instantiation

  /// Test API Key for development (both iOS and Android)
  /// Set via environment variable: REVENUECAT_TEST_API_KEY
  static const String testApiKey = String.fromEnvironment(
    'REVENUECAT_TEST_API_KEY',
    defaultValue: '',
  );

  /// iOS/macOS API Key for com.stuffrite.app (production)
  /// Set via environment variable: REVENUECAT_IOS_API_KEY
  static const String iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );

  /// Android API Key for com.stuffrite.app (production)
  /// Set via environment variable: REVENUECAT_ANDROID_API_KEY
  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  /// Premium entitlement identifier
  /// This matches the "Stuffrite Unlocked" entitlement in RevenueCat Dashboard
  /// Both 'monthly' and 'yearly' products are attached to this entitlement
  /// NOTE: Using the display name because that's what RevenueCat is returning
  static const String premiumEntitlementId = 'Stuffrite Unlocked';

  /// VIP users who get free access (dev bypass)
  /// REMINDER: Remove or gate this before production release!
  static const List<String> vipEmails = [
    'psul7an@gmail.com', // Developer Bypass
    'telmccall@gmail.com', // Owner
    'lizzi_fish@yahoo.com', // Tester
  ];

  /// Check if an email is a VIP user
  static bool isVipUser(String? email) {
    if (email == null) return false;
    return vipEmails.contains(email.toLowerCase());
  }

  /// Check if customer has premium entitlement
  /// Returns true if "Stuffrite Unlocked" entitlement is active
  static bool hasPremiumEntitlement(Map<String, dynamic> activeEntitlements) {

    final hasPremium = activeEntitlements.containsKey(premiumEntitlementId);

    if (hasPremium) {
    } else {
    }

    return hasPremium;
  }
}
