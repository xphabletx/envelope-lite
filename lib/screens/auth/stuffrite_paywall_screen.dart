// lib/screens/auth/stuffrite_paywall_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/auth_service.dart';
import '../../config/revenue_cat_config.dart';

/// Custom Branded Paywall Screen - Latte Love Theme
///
/// Fully branded paywall experience that showcases Stuffrite Premium features
/// Uses the Latte Love theme colors and Stuffrite logo for brand consistency
class StuffritePaywallScreen extends StatefulWidget {
  const StuffritePaywallScreen({super.key});

  @override
  State<StuffritePaywallScreen> createState() => _StuffritePaywallScreenState();
}

class _StuffritePaywallScreenState extends State<StuffritePaywallScreen> {
  bool _isCheckingSubscription = false;
  bool _isLoadingOfferings = true;
  bool _isPurchasing = false;
  Offering? _offering;
  Package? _selectedPackage;
  String? _errorMessage;

  // Latte Love theme colors (extracted from app_themes.dart)
  static const Color _creamBackground = Color(0xFFF5F0E8);
  static const Color _brownPrimary = Color(0xFF8B6F47);
  static const Color _darkBrown = Color(0xFF5C4033);
  static const Color _goldAccent = Color(0xFFD4AF37);
  static const Color _surfaceCream = Color(0xFFE8DFD0);

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creamBackground,
      body: SafeArea(
        child: _isCheckingSubscription
            ? _buildCheckingSubscription()
            : _isLoadingOfferings
                ? _buildLoadingOfferings()
                : _buildPaywallContent(),
      ),
    );
  }

  /// Loading state while checking subscription
  Widget _buildCheckingSubscription() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _brownPrimary),
          const SizedBox(height: 16),
          Text(
            'Checking subscription status...',
            style: TextStyle(
              color: _darkBrown,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Loading state while fetching offerings
  Widget _buildLoadingOfferings() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _brownPrimary),
          const SizedBox(height: 16),
          Text(
            'Loading subscription options...',
            style: TextStyle(
              color: _darkBrown,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Main paywall content
  Widget _buildPaywallContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logout button (top right)
            Align(
              alignment: Alignment.topRight,
              child: TextButton.icon(
                onPressed: _handleLogout,
                icon: Icon(Icons.logout, color: _darkBrown, size: 20),
                label: Text(
                  'Sign Out',
                  style: TextStyle(color: _darkBrown, fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Stuffrite Logo
            Image.asset(
              'assets/logo/splash_screen_stuffrite.png',
              height: 180,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 32),

            // Premium Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _goldAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'PREMIUM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'Unlock Stuffrite Premium',
              style: TextStyle(
                color: _darkBrown,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Everything you need to organize your life',
              style: TextStyle(
                color: _brownPrimary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Features List
            _buildFeatureItem(
              icon: Icons.cloud_sync_rounded,
              title: 'Cloud Sync',
              description: 'Access your binders across all devices',
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.folder_special_rounded,
              title: 'Unlimited Binders',
              description: 'Create as many binders as you need',
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.people_rounded,
              title: 'Shared Workspaces',
              description: 'Collaborate with family and teams',
            ),

            const SizedBox(height: 40),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Subscription options
            if (_offering != null) _buildSubscriptionOptions(),

            const SizedBox(height: 24),

            // Subscribe button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_selectedPackage != null && !_isPurchasing)
                    ? _handlePurchase
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brownPrimary,
                  disabledBackgroundColor: _brownPrimary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isPurchasing
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Subscribe Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Restore purchases button
            TextButton(
              onPressed: _isPurchasing ? null : _handleRestore,
              child: Text(
                'Restore Purchases',
                style: TextStyle(
                  color: _brownPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Terms and privacy
            Text(
              'Auto-renewable subscription. Cancel anytime.',
              style: TextStyle(
                color: _brownPrimary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Feature item widget
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceCream,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _brownPrimary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brownPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _darkBrown,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: _brownPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Subscription options (Monthly/Annual)
  Widget _buildSubscriptionOptions() {
    final packages = _offering!.availablePackages;

    // Try to find monthly and annual packages
    final monthlyPackage = packages.firstWhere(
      (p) => p.packageType == PackageType.monthly,
      orElse: () => packages.first,
    );
    final annualPackage = packages.firstWhere(
      (p) => p.packageType == PackageType.annual,
      orElse: () => packages.length > 1 ? packages[1] : packages.first,
    );

    // Auto-select annual if available, otherwise monthly
    _selectedPackage ??= annualPackage;

    return Column(
      children: [
        // Monthly option
        _buildSubscriptionOption(
          package: monthlyPackage,
          title: 'Monthly',
          price: monthlyPackage.storeProduct.priceString,
          description: 'Billed monthly',
          isRecommended: false,
        ),
        const SizedBox(height: 12),
        // Annual option (recommended)
        _buildSubscriptionOption(
          package: annualPackage,
          title: 'Annual',
          price: annualPackage.storeProduct.priceString,
          description: 'Best value - save ${_calculateSavings(monthlyPackage, annualPackage)}',
          isRecommended: true,
        ),
      ],
    );
  }

  /// Subscription option card
  Widget _buildSubscriptionOption({
    required Package package,
    required String title,
    required String price,
    required String description,
    required bool isRecommended,
  }) {
    final isSelected = _selectedPackage?.identifier == package.identifier;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackage = package;
          _errorMessage = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? _brownPrimary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _brownPrimary : _surfaceCream,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _brownPrimary : _brownPrimary.withValues(alpha: 0.3),
                  width: 2,
                ),
                color: isSelected ? _brownPrimary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _darkBrown,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _goldAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: _brownPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Text(
              price,
              style: TextStyle(
                color: _darkBrown,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate savings percentage for annual vs monthly
  String _calculateSavings(Package monthly, Package annual) {
    try {
      final monthlyPrice = monthly.storeProduct.price;
      final annualPrice = annual.storeProduct.price;
      final monthlyCost = monthlyPrice * 12;
      final savings = ((monthlyCost - annualPrice) / monthlyCost * 100).round();
      return '$savings%';
    } catch (e) {
      return '20%';
    }
  }

  /// Load available offerings from RevenueCat
  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        setState(() {
          _offering = offerings.current;
          _isLoadingOfferings = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No subscription plans available. Please try again later.';
          _isLoadingOfferings = false;
        });
      }
    } catch (e) {
      debugPrint('[StuffritePaywall] Error loading offerings: $e');
      setState(() {
        _errorMessage = 'Failed to load subscription plans. Please check your connection.';
        _isLoadingOfferings = false;
      });
    }
  }

  /// Handle purchase
  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) return;

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final purchaseParams = PurchaseParams.package(_selectedPackage!);
      final purchaseResult = await Purchases.purchase(purchaseParams);

      debugPrint('[StuffritePaywall] Purchase completed: ${purchaseResult.customerInfo.entitlements.active}');

      // Debug: Print ALL entitlement keys to see what RevenueCat SDK is seeing
      debugPrint('[StuffritePaywall] 🔍 Checking for entitlement: "${RevenueCatConfig.premiumEntitlementId}"');
      debugPrint('[StuffritePaywall] 🔍 ALL entitlement keys after purchase: ${purchaseResult.customerInfo.entitlements.all.keys.toList()}');
      debugPrint('[StuffritePaywall] 🔍 Active entitlement keys after purchase: ${purchaseResult.customerInfo.entitlements.active.keys.toList()}');

      // Check if the premium entitlement is active
      final entitlement = purchaseResult.customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId];
      final hasPremium = entitlement?.isActive ?? false;

      if (entitlement != null) {
        debugPrint('[StuffritePaywall] 🔍 Entitlement "${RevenueCatConfig.premiumEntitlementId}" found - isActive: ${entitlement.isActive}');
      } else {
        debugPrint('[StuffritePaywall] ⚠️ Entitlement "${RevenueCatConfig.premiumEntitlementId}" NOT FOUND');
      }

      if (hasPremium) {
        debugPrint('[StuffritePaywall] ✅ Premium entitlement unlocked!');
        // Check and dismiss to trigger app rebuild
        await _checkAndDismiss();
      } else {
        debugPrint('[StuffritePaywall] ⚠️ Purchase completed but entitlement not active');
        setState(() {
          _isPurchasing = false;
          _errorMessage = 'Purchase completed but subscription not activated. Please contact support.';
        });
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('[StuffritePaywall] Purchase error code: $errorCode');

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled - just reset state, no error message
        debugPrint('[StuffritePaywall] Purchase cancelled by user');
        setState(() {
          _isPurchasing = false;
        });
      } else {
        // Other error - show error message
        debugPrint('[StuffritePaywall] Purchase failed: ${e.message}');
        setState(() {
          _isPurchasing = false;
          _errorMessage = e.message ?? 'Purchase failed. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('[StuffritePaywall] Unexpected purchase error: $e');
      setState(() {
        _isPurchasing = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  /// Handle restore purchases
  Future<void> _handleRestore() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final customerInfo = await Purchases.restorePurchases();
      debugPrint('[StuffritePaywall] Restore completed: ${customerInfo.entitlements.active}');

      // Debug: Print ALL entitlement keys to see what RevenueCat SDK is seeing
      debugPrint('[StuffritePaywall] 🔍 Checking for entitlement: "${RevenueCatConfig.premiumEntitlementId}"');
      debugPrint('[StuffritePaywall] 🔍 ALL entitlement keys after restore: ${customerInfo.entitlements.all.keys.toList()}');
      debugPrint('[StuffritePaywall] 🔍 Active entitlement keys after restore: ${customerInfo.entitlements.active.keys.toList()}');

      // Check if the premium entitlement is active after restore
      final entitlement = customerInfo.entitlements.all[RevenueCatConfig.premiumEntitlementId];
      final hasPremium = entitlement?.isActive ?? false;

      if (entitlement != null) {
        debugPrint('[StuffritePaywall] 🔍 Entitlement "${RevenueCatConfig.premiumEntitlementId}" found - isActive: ${entitlement.isActive}');
      } else {
        debugPrint('[StuffritePaywall] ⚠️ Entitlement "${RevenueCatConfig.premiumEntitlementId}" NOT FOUND');
      }

      if (hasPremium) {
        debugPrint('[StuffritePaywall] ✅ Purchases restored successfully!');
        // Check and dismiss to trigger app rebuild
        await _checkAndDismiss();
      } else {
        debugPrint('[StuffritePaywall] ⚠️ No active subscriptions found');
        setState(() {
          _isPurchasing = false;
          _errorMessage = 'No active subscriptions found. Please purchase a subscription or contact support.';
        });
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('[StuffritePaywall] Restore error code: $errorCode');
      debugPrint('[StuffritePaywall] Restore failed: ${e.message}');

      setState(() {
        _isPurchasing = false;
        _errorMessage = e.message ?? 'Failed to restore purchases. Please try again.';
      });
    } catch (e) {
      debugPrint('[StuffritePaywall] Unexpected restore error: $e');
      setState(() {
        _isPurchasing = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  /// Check subscription status and dismiss if user has premium
  Future<void> _checkAndDismiss() async {
    setState(() => _isCheckingSubscription = true);

    try {
      final customerInfo = await Purchases.getCustomerInfo();

      // Debug: Print ALL entitlement keys to see what's available
      debugPrint('[StuffritePaywall] 🔍 [CHECK_AND_DISMISS] Checking for entitlement: "${RevenueCatConfig.premiumEntitlementId}"');
      debugPrint('[StuffritePaywall] 🔍 [CHECK_AND_DISMISS] ALL entitlement keys: ${customerInfo.entitlements.all.keys.toList()}');
      debugPrint('[StuffritePaywall] 🔍 [CHECK_AND_DISMISS] Active entitlement keys: ${customerInfo.entitlements.active.keys.toList()}');

      // If active is empty, print details about ALL entitlements
      if (customerInfo.entitlements.active.isEmpty) {
        debugPrint('[StuffritePaywall] ⚠️ No active entitlements found!');
        debugPrint('[StuffritePaywall] 🔍 Inspecting ALL entitlements:');
        for (var key in customerInfo.entitlements.all.keys) {
          final entitlement = customerInfo.entitlements.all[key];
          debugPrint('[StuffritePaywall]   - "$key": isActive=${entitlement?.isActive}, identifier=${entitlement?.identifier}');
        }
      }

      // Check for premium entitlement
      final hasPremium = RevenueCatConfig.hasPremiumEntitlement(
        customerInfo.entitlements.active,
      );

      if (hasPremium) {
        debugPrint('[StuffritePaywall] ✅ Premium entitlement active - allowing access');
        // The AuthWrapper will automatically rebuild and show HomeScreen
        // No need to manually navigate
      } else {
        debugPrint('[StuffritePaywall] ⚠️ No premium entitlement - staying on paywall');
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _isCheckingSubscription = false;
            _errorMessage = 'Subscribe to Stuffrite Premium to access all features';
          });
        }
      }
    } catch (e) {
      debugPrint('[StuffritePaywall] ❌ Error checking subscription: $e');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isCheckingSubscription = false;
          _errorMessage = 'Error verifying subscription. Please try again.';
        });
      }
    }
  }

  /// Handle logout - allows users to exit the app if they don't want to subscribe
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out?',
          style: TextStyle(color: _darkBrown),
        ),
        content: Text(
          'You need a Stuffrite Premium subscription to use this app. '
          'Would you like to sign out?',
          style: TextStyle(color: _brownPrimary),
        ),
        backgroundColor: _surfaceCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _brownPrimary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brownPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
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
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }
}
