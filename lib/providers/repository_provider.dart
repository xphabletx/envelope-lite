import 'package:flutter/foundation.dart';
import '../services/envelope_repo.dart';
import '../services/account_repo.dart';
import '../services/scheduled_payment_repo.dart';
import '../services/notification_repo.dart';

/// Provider that holds initialized repositories
///
/// Repositories are created during the splash screen to prevent
/// loading delays on the home screen. This provider ensures:
/// 1. Repositories are initialized once during splash
/// 2. HomeScreen has immediate access to ready repositories
/// 3. Repositories are properly disposed on logout
class RepositoryProvider extends ChangeNotifier {
  EnvelopeRepo? _envelopeRepo;
  AccountRepo? _accountRepo;
  ScheduledPaymentRepo? _scheduledPaymentRepo;
  NotificationRepo? _notificationRepo;

  EnvelopeRepo? get envelopeRepo => _envelopeRepo;
  AccountRepo? get accountRepo => _accountRepo;
  ScheduledPaymentRepo? get scheduledPaymentRepo => _scheduledPaymentRepo;
  NotificationRepo? get notificationRepo => _notificationRepo;

  bool get areRepositoriesInitialized =>
      _envelopeRepo != null &&
      _accountRepo != null &&
      _scheduledPaymentRepo != null &&
      _notificationRepo != null;

  /// Initialize all repositories for a logged-in user
  /// Called during splash screen to prevent home screen loading delays
  Future<void> initializeRepositories({
    required EnvelopeRepo envelopeRepo,
    required AccountRepo accountRepo,
    required ScheduledPaymentRepo scheduledPaymentRepo,
    required NotificationRepo notificationRepo,
  }) async {
    _envelopeRepo = envelopeRepo;
    _accountRepo = accountRepo;
    _scheduledPaymentRepo = scheduledPaymentRepo;
    _notificationRepo = notificationRepo;

    // Clean up any orphaned scheduled payments from deleted envelopes
    // This is a one-time migration for existing users
    try {
      final cleanedCount = await envelopeRepo.cleanupOrphanedScheduledPayments();
      if (cleanedCount > 0) {
        debugPrint('[RepositoryProvider] Cleaned up $cleanedCount orphaned scheduled payments');
      }
    } catch (e) {
      debugPrint('[RepositoryProvider] Failed to cleanup orphaned payments: $e');
    }

    notifyListeners();
  }

  /// Clear all repositories (called on logout)
  void clearRepositories() {
    _envelopeRepo = null;
    _accountRepo = null;
    _scheduledPaymentRepo = null;
    _notificationRepo = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clearRepositories();
    super.dispose();
  }
}
