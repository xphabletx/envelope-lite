// lib/services/customer_center_service.dart
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:flutter/services.dart';

/// Service to manage RevenueCat Customer Center
///
/// Customer Center provides a pre-built UI for:
/// - Viewing subscription status
/// - Managing subscriptions
/// - Restoring purchases
/// - Accessing support
class CustomerCenterService {
  /// Present RevenueCat Customer Center
  ///
  /// This shows a native UI for managing subscriptions
  /// Returns true if successfully presented, false otherwise
  static Future<bool> presentCustomerCenter(BuildContext context) async {
    try {
      debugPrint('[CustomerCenter] Presenting Customer Center...');

      await RevenueCatUI.presentCustomerCenter();

      debugPrint('[CustomerCenter] ✅ Customer Center presented successfully');
      return true;
    } on PlatformException catch (e) {
      debugPrint('[CustomerCenter] ❌ Platform error: ${e.message}');

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
      debugPrint('[CustomerCenter] ❌ Unexpected error: $e');

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
