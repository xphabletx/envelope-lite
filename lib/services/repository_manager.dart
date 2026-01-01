// lib/services/repository_manager.dart
import 'package:flutter/foundation.dart';
import 'envelope_repo.dart';
import 'account_repo.dart';
import 'scheduled_payment_repo.dart';
import 'notification_repo.dart';

/// Global singleton to manage repository lifecycle
///
/// This manager tracks all active repositories and provides a centralized
/// way to dispose them during logout, preventing PERMISSION_DENIED errors
/// from Firestore streams that try to access data after auth state changes.
///
/// Usage:
/// - Call registerRepositories() when creating repos in HomeScreenWrapper
/// - Call disposeAllRepositories() in AuthService.signOut() before clearing data
class RepositoryManager {
  static final RepositoryManager _instance = RepositoryManager._internal();
  factory RepositoryManager() => _instance;
  RepositoryManager._internal();

  // Track active repositories
  EnvelopeRepo? _envelopeRepo;
  AccountRepo? _accountRepo;
  ScheduledPaymentRepo? _scheduledPaymentRepo;
  NotificationRepo? _notificationRepo;

  /// Register repositories when they're created
  void registerRepositories({
    EnvelopeRepo? envelopeRepo,
    AccountRepo? accountRepo,
    ScheduledPaymentRepo? scheduledPaymentRepo,
    NotificationRepo? notificationRepo,
  }) {
    _envelopeRepo = envelopeRepo;
    _accountRepo = accountRepo;
    _scheduledPaymentRepo = scheduledPaymentRepo;
    _notificationRepo = notificationRepo;

    debugPrint('[RepositoryManager] ✅ Registered repositories:');
    if (_envelopeRepo != null) debugPrint('  - EnvelopeRepo');
    if (_accountRepo != null) debugPrint('  - AccountRepo');
    if (_scheduledPaymentRepo != null) debugPrint('  - ScheduledPaymentRepo');
    if (_notificationRepo != null) debugPrint('  - NotificationRepo');
  }

  /// Dispose all registered repositories
  ///
  /// CRITICAL: Call this BEFORE clearing Hive data during logout
  /// to prevent PERMISSION_DENIED errors from Firestore streams
  void disposeAllRepositories() {
    debugPrint('[RepositoryManager] 🔄 Disposing all repositories...');

    _envelopeRepo?.dispose();
    _accountRepo?.dispose();
    _scheduledPaymentRepo?.dispose();
    _notificationRepo?.dispose();

    // Clear references
    _envelopeRepo = null;
    _accountRepo = null;
    _scheduledPaymentRepo = null;
    _notificationRepo = null;

    debugPrint('[RepositoryManager] ✅ All repositories disposed');
  }

  /// Check if any repositories are registered
  bool get hasActiveRepositories =>
      _envelopeRepo != null ||
      _accountRepo != null ||
      _scheduledPaymentRepo != null ||
      _notificationRepo != null;
}
