import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auto_payment_service.dart'; // Assuming this path

class AppLifecycleObserver extends StatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _processPaymentsOnResume();
    }
  }

  Future<void> _processPaymentsOnResume() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final autoPaymentService = AutoPaymentService(); // Instantiate the service
      await autoPaymentService.processDuePayments(userId);
      // Optionally, add logging or a snackbar to confirm execution
      debugPrint('Processed due payments on app resume for user: $userId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
