// lib/screens/auth/stuffrite_paywall_screen.dart
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../services/auth_service.dart';

/// Hard paywall screen using RevenueCat PaywallView
/// Blocks all app features until user subscribes to Stuffrite Premium
class StuffritePaywallScreen extends StatefulWidget {
  const StuffritePaywallScreen({super.key});

  @override
  State<StuffritePaywallScreen> createState() => _StuffritePaywallScreenState();
}

class _StuffritePaywallScreenState extends State<StuffritePaywallScreen> {
  bool _isCheckingSubscription = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stuffrite Premium'),
        automaticallyImplyLeading: false, // Remove back button
        actions: [
          // Logout button - ensures users can exit if they don't want to subscribe
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isCheckingSubscription
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking subscription status...'),
                ],
              ),
            )
          : PaywallView(
              displayCloseButton: false, // We handle our own logout button
              onPurchaseCompleted: (customerInfo, storeTransaction) => _checkAndDismiss(),
              onRestoreCompleted: (customerInfo) => _checkAndDismiss(),
              onDismiss: () => _checkAndDismiss(),
            ),
    );
  }

  /// Check subscription status and dismiss if user has premium
  Future<void> _checkAndDismiss() async {
    setState(() => _isCheckingSubscription = true);

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final hasPremium = customerInfo.entitlements.active.containsKey('Stuffrite Premium');

      if (hasPremium) {
        debugPrint('[StuffritePaywall] ✅ Premium entitlement active - allowing access');
        // The AuthWrapper will automatically rebuild and show HomeScreen
        // No need to manually navigate
      } else {
        debugPrint('[StuffritePaywall] ⚠️ No premium entitlement - staying on paywall');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscribe to Stuffrite Premium to access all features'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[StuffritePaywall] ❌ Error checking subscription: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingSubscription = false);
      }
    }
  }

  /// Handle logout - allows users to exit the app if they don't want to subscribe
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'You need a Stuffrite Premium subscription to use this app. '
          'Would you like to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await AuthService.signOut();
        // AuthWrapper will automatically redirect to SignInScreen
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }
}
