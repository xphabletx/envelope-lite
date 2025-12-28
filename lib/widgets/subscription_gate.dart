// lib/widgets/subscription_gate.dart
import 'package:flutter/material.dart';
import '../services/paywall_service.dart';
import '../screens/paywall_screen.dart';

/// Widget that shows paywall if user doesn't have active subscription
///
/// NOTE: This is currently disabled. To enable subscription gating,
/// uncomment the logic in the _checkSubscription method.
class SubscriptionGate extends StatefulWidget {
  const SubscriptionGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  final _paywallService = PaywallService();
  // ignore: unused_field
  bool _hasSubscription = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    final hasSubscription = await _paywallService.hasActiveSubscription();

    setState(() {
      _hasSubscription = hasSubscription;
      _loading = false;
    });

    // NOTE: Subscription gate is disabled for now
    // To enable, uncomment the following code:

    // If no subscription, show paywall after short delay
    // if (!hasSubscription) {
    //   await Future.delayed(const Duration(seconds: 1));
    //   if (mounted) {
    //     _showPaywall();
    //   }
    // }
  }

  // ignore: unused_element
  Future<void> _showPaywall() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );

    if (result == true) {
      // User subscribed, refresh
      _checkSubscription();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Always show the child for now (subscription gate disabled)
    return widget.child;
  }
}
