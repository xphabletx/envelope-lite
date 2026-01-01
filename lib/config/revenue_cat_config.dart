// lib/config/revenue_cat_config.dart

/// RevenueCat configuration for Stuffrite (com.stuffrite.app)
///
/// SECURITY WARNING: These keys are production API keys.
/// - DO NOT commit to public repositories
/// - Consider using environment variables or secret management for production
/// - These keys are read-only and cannot be used to make purchases
class RevenueCatConfig {
  RevenueCatConfig._(); // Private constructor to prevent instantiation

  /// Test API Key for development (both iOS and Android)
  static const String testApiKey = 'test_XscvJsnJmhZKbBRKzlDSYpBltbA';

  /// iOS/macOS API Key for com.stuffrite.app (production)
  static const String iosApiKey = 'REDACTED_IOS_KEY';

  /// Android API Key for com.stuffrite.app (production)
  static const String androidApiKey = 'REDACTED_ANDROID_KEY';

  /// Premium entitlement identifier
  /// This is the entitlement ID configured in RevenueCat dashboard
  static const String premiumEntitlementId = 'Stuffrite Premium';

  /// VIP users who get free access (dev bypass)
  /// REMINDER: Remove or gate this before production release!
  static const List<String> vipEmails = [
    'psul7an@gmail.com', // Developer
    // Add partner email here if needed
  ];

  /// Check if an email is a VIP user
  static bool isVipUser(String? email) {
    if (email == null) return false;
    return vipEmails.contains(email.toLowerCase());
  }
}
