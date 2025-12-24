import 'package:flutter/widgets.dart';
import '../services/envelope_repo.dart';
import '../services/scheduled_payment_repo.dart';
import '../services/notification_repo.dart';
import '../services/scheduled_payment_processor.dart';

class AppLifecycleObserver extends StatefulWidget {
  const AppLifecycleObserver({
    super.key,
    required this.child,
    required this.envelopeRepo,
    required this.paymentRepo,
    required this.notificationRepo,
  });

  final Widget child;
  final EnvelopeRepo envelopeRepo;
  final ScheduledPaymentRepo paymentRepo;
  final NotificationRepo notificationRepo;

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Process on first load
    _processPaymentsOnResume();
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
    try {
      final processor = ScheduledPaymentProcessor();
      final result = await processor.processAutomaticPayments(
        userId: widget.envelopeRepo.currentUserId,
        envelopeRepo: widget.envelopeRepo,
        paymentRepo: widget.paymentRepo,
        notificationRepo: widget.notificationRepo,
      );

      if (result.processedCount > 0) {
        debugPrint('Processed ${result.processedCount} scheduled payments');
      }
    } catch (e) {
      debugPrint('Error processing scheduled payments on resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
