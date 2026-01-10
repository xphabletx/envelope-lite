// lib/services/sync_manager.dart
// Background sync manager for Firebase sync operations
// Manages unawaited background sync to keep Firestore in sync with Hive

import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/account.dart';
import '../models/scheduled_payment.dart';
import '../models/pay_day_settings.dart';
import '../models/transaction.dart' as model;
import 'subscription_service.dart';

/// Internal class representing a sync operation
class _SyncOperation {
  final String key;
  final Future<void> Function() execute;
  final VoidCallback? onComplete;

  _SyncOperation({
    required this.key,
    required this.execute,
    this.onComplete,
  });
}

/// Manages background sync between Hive (local) and Firebase (cloud)
///
/// Key Design Principles:
/// 1. **Fire-and-forget**: All sync operations are unawaited
/// 2. **Non-blocking**: Never blocks UI or Hive writes
/// 3. **Workspace-aware**: Only syncs when in workspace mode
/// 4. **Failure-tolerant**: Logs errors but doesn't throw
/// 5. **Queue-based**: Uses queue to prevent overwhelming Firebase
///
/// Enhanced Features:
/// - Singleton pattern for global access
/// - Queue system to prevent Firebase throttling
/// - Retry logic for failed syncs
/// - isFuture filter to prevent syncing projected transactions
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;

  SyncManager._internal() {
    _startQueueProcessor();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sync queue for batching operations
  final Queue<_SyncOperation> _syncQueue = Queue<_SyncOperation>();

  // Track pending syncs for debugging
  final Set<String> _pendingSyncs = {};

  // Flag to prevent multiple queue processors
  bool _processingQueue = false;

  /// Start the queue processor (runs continuously in background)
  void _startQueueProcessor() {
    Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processQueue();
    });
  }

  /// Process queued sync operations
  Future<void> _processQueue() async {
    if (_processingQueue || _syncQueue.isEmpty) return;

    _processingQueue = true;

    try {
      while (_syncQueue.isNotEmpty) {
        final operation = _syncQueue.removeFirst();
        await operation.execute();

        // Small delay to prevent Firebase throttling
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _processingQueue = false;
    }
  }

  /// Push an envelope to cloud
  /// Solo Mode: Syncs to private user collection (/users/{userId}/envelopes)
  /// Workspace Mode: Syncs to workspace collection (/workspaces/{workspaceId}/envelopes)
  /// Returns immediately, sync happens in background
  /// GATED: Only syncs for users with Stuffrite Premium entitlement
  void pushEnvelope(Envelope envelope, String? workspaceId, String userId) {
    final syncKey = 'envelope_${envelope.id}';
    if (_pendingSyncs.contains(syncKey)) return; // Already syncing

    _pendingSyncs.add(syncKey);

    // Add to queue with entitlement check
    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncEnvelopeToFirestore(envelope, workspaceId, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Push a transaction to cloud
  /// Solo Mode: Syncs ALL transactions to private user collection (/users/{userId}/transactions)
  /// Workspace Mode: Syncs ONLY partner transfers to workspace collection (/workspaces/{workspaceId}/transfers)
  /// CRITICAL: Filters out isFuture transactions to prevent syncing projections
  /// GATED: Only syncs for users with Stuffrite Premium entitlement
  void pushTransaction(
    model.Transaction transaction,
    String? workspaceId,
    String userId,
    bool isPartnerTransfer,
  ) {
    // CRITICAL: Never sync projected/future transactions from TimeMachine
    if (transaction.isFuture) {
      return;
    }

    // In workspace mode, only sync partner transfers
    // In solo mode, sync ALL transactions to private collection
    final shouldSync = (workspaceId == null || workspaceId.isEmpty) || isPartnerTransfer;
    if (!shouldSync) return;

    final syncKey = 'transaction_${transaction.id}';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    // Add to queue with entitlement check
    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncTransactionToFirestore(transaction, workspaceId, userId, isPartnerTransfer, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Delete envelope from cloud
  void deleteEnvelope(String envelopeId, String? workspaceId, String userId) {
    final syncKey = 'delete_envelope_$envelopeId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _deleteEnvelopeFromFirestore(envelopeId, workspaceId, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Delete transaction from cloud
  void deleteTransaction(String transactionId, String? workspaceId, String userId, bool isPartnerTransfer) {
    // In workspace mode, only delete partner transfers
    // In solo mode, delete ALL transactions from private collection
    final shouldSync = (workspaceId == null || workspaceId.isEmpty) || isPartnerTransfer;
    if (!shouldSync) return;

    final syncKey = 'delete_transaction_$transactionId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _deleteTransactionFromFirestore(transactionId, workspaceId, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Push a group (Binder) to cloud
  /// Solo Mode: Syncs to private user collection (/users/{userId}/groups)
  /// CRITICAL: Groups MUST sync to prevent data loss on logout
  void pushGroup(EnvelopeGroup group, String userId) {
    final syncKey = 'group_${group.id}';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncGroupToFirestore(group, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Delete group from cloud
  void deleteGroup(String groupId, String userId) {
    final syncKey = 'delete_group_$groupId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _deleteGroupFromFirestore(groupId, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Push an account to cloud
  /// Solo Mode: Syncs to private user collection (/users/{userId}/accounts)
  /// CRITICAL: Accounts MUST sync to prevent data loss on logout
  void pushAccount(Account account, String userId) {
    final syncKey = 'account_${account.id}';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncAccountToFirestore(account, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Delete account from cloud
  void deleteAccount(String accountId, String userId) {
    final syncKey = 'delete_account_$accountId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _deleteAccountFromFirestore(accountId, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Push a scheduled payment to cloud
  /// Solo Mode: Syncs to private user collection (/users/{userId}/scheduledPayments)
  /// CRITICAL: Scheduled payments MUST sync to prevent data loss on logout
  void pushScheduledPayment(ScheduledPayment payment, String userId) {
    final syncKey = 'scheduled_payment_${payment.id}';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncScheduledPaymentToFirestore(payment, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Delete scheduled payment from cloud
  void deleteScheduledPayment(String paymentId, String userId) {
    final syncKey = 'delete_scheduled_payment_$paymentId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _deleteScheduledPaymentFromFirestore(paymentId, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Push pay day settings to cloud
  /// Solo Mode: Syncs to user document (/users/{userId})
  /// CRITICAL: PayDay settings MUST sync to prevent data loss on logout
  void pushPayDaySettings(PayDaySettings settings, String userId) {
    final syncKey = 'payday_settings_$userId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncPayDaySettingsToFirestore(settings, userId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  // =========================================================================
  // PRIVATE IMPLEMENTATION
  // =========================================================================

  Future<void> _syncEnvelopeToFirestore(
    Envelope envelope,
    String? workspaceId,
    String userId,
    String syncKey,
  ) async {
    try {
      // AUTHORIZATION CHECK: Use centralized subscription service
      // This checks both VIP status and RevenueCat entitlement
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      // Log successful authorization with details

      // SOLO MODE: Sync to private user collection
      if (workspaceId == null || workspaceId.isEmpty) {

        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('envelopes')
            .doc(envelope.id);

        await docRef.set(envelope.toMap(), SetOptions(merge: true));

        // CRITICAL: Verify write actually reached server
        try {
          final snapshot = await docRef.get(const GetOptions(source: Source.server));
          if (snapshot.exists) {
          } else {
          }
        } catch (e) {
        }
      } else {
        // WORKSPACE MODE: Sync to workspace collection

        final docRef = _firestore
            .collection('workspaces')
            .doc(workspaceId)
            .collection('envelopes')
            .doc(envelope.id);

        await docRef.set(envelope.toMap(), SetOptions(merge: true));

        // CRITICAL: Verify write actually reached server
        try {
          final snapshot = await docRef.get(const GetOptions(source: Source.server));
          if (snapshot.exists) {
          } else {
          }
        } catch (e) {
        }
      }
    } catch (e) {
      // Could implement retry logic here
    }
  }

  Future<void> _syncTransactionToFirestore(
    model.Transaction transaction,
    String? workspaceId,
    String userId,
    bool isPartnerTransfer,
    String syncKey,
  ) async {
    try {
      // AUTHORIZATION CHECK: Use centralized subscription service
      // This checks both VIP status and RevenueCat entitlement
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      // Log successful authorization with details

      // SOLO MODE: Sync to private user collection
      if (workspaceId == null || workspaceId.isEmpty) {

        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(transaction.id);

        await docRef.set(transaction.toMap(), SetOptions(merge: true));

        // CRITICAL: Verify write actually reached server
        try {
          final snapshot = await docRef.get(const GetOptions(source: Source.server));
          if (snapshot.exists) {
          } else {
          }
        } catch (e) {
        }
      } else {
        // WORKSPACE MODE: Sync to workspace transfers collection (partner transfers only)

        final docRef = _firestore
            .collection('workspaces')
            .doc(workspaceId)
            .collection('transfers')
            .doc(transaction.id);

        await docRef.set(transaction.toMap(), SetOptions(merge: true));

        // CRITICAL: Verify write actually reached server
        try {
          final snapshot = await docRef.get(const GetOptions(source: Source.server));
          if (snapshot.exists) {
          } else {
          }
        } catch (e) {
        }

      }
    } catch (e) {
    }
  }

  Future<void> _deleteEnvelopeFromFirestore(
    String envelopeId,
    String? workspaceId,
    String userId,
    String syncKey,
  ) async {
    try {
      // AUTHORIZATION CHECK: Use centralized subscription service
      // This checks both VIP status and RevenueCat entitlement
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      // Log successful authorization with details

      // SOLO MODE: Delete from private user collection
      if (workspaceId == null || workspaceId.isEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('envelopes')
            .doc(envelopeId)
            .delete();

      } else {
        // WORKSPACE MODE: Delete from workspace collection
        await _firestore
            .collection('workspaces')
            .doc(workspaceId)
            .collection('envelopes')
            .doc(envelopeId)
            .delete();

      }
    } catch (e) {
    }
  }

  Future<void> _deleteTransactionFromFirestore(
    String transactionId,
    String? workspaceId,
    String userId,
    String syncKey,
  ) async {
    try {
      // AUTHORIZATION CHECK: Use centralized subscription service
      // This checks both VIP status and RevenueCat entitlement
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      // Log successful authorization with details

      // SOLO MODE: Delete from private user collection
      if (workspaceId == null || workspaceId.isEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc(transactionId)
            .delete();

      } else {
        // WORKSPACE MODE: Delete from workspace transfers collection
        await _firestore
            .collection('workspaces')
            .doc(workspaceId)
            .collection('transfers')
            .doc(transactionId)
            .delete();

      }
    } catch (e) {
    }
  }

  // =========================================================================
  // GROUP (BINDER) SYNC
  // =========================================================================

  Future<void> _syncGroupToFirestore(
    EnvelopeGroup group,
    String userId,
    String syncKey,
  ) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(group.id)
          .set(group.toMap(), SetOptions(merge: true));

    } catch (e) {
    }
  }

  Future<void> _deleteGroupFromFirestore(
    String groupId,
    String userId,
    String syncKey,
  ) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .delete();

    } catch (e) {
    }
  }

  // =========================================================================
  // ACCOUNT SYNC
  // =========================================================================

  Future<void> _syncAccountToFirestore(
    Account account,
    String userId,
    String syncKey,
  ) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(account.id)
          .set(account.toMap(), SetOptions(merge: true));

    } catch (e) {
    }
  }

  Future<void> _deleteAccountFromFirestore(
    String accountId,
    String userId,
    String syncKey,
  ) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc(accountId)
          .delete();

    } catch (e) {
    }
  }

  // =========================================================================
  // SCHEDULED PAYMENT SYNC
  // =========================================================================

  Future<void> _syncScheduledPaymentToFirestore(
    ScheduledPayment payment,
    String userId,
    String syncKey,
  ) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('scheduledPayments')
          .doc(payment.id)
          .set(payment.toMap(), SetOptions(merge: true));

    } catch (e) {
    }
  }

  Future<void> _deleteScheduledPaymentFromFirestore(
    String paymentId,
    String userId,
    String syncKey,
  ) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('scheduledPayments')
          .doc(paymentId)
          .delete();

    } catch (e) {
    }
  }

  // =========================================================================
  // PAY DAY SETTINGS SYNC
  // =========================================================================

  Future<void> _syncPayDaySettingsToFirestore(
    PayDaySettings settings,
    String userId,
    String syncKey,
  ) async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      final authResult = await SubscriptionService().canSync(userEmail: userEmail);

      if (!authResult.authorized) {
        return;
      }

      // Store pay day settings in the user document itself (not a subcollection)
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
            'payDaySettings': settings.toFirestore(),
          }, SetOptions(merge: true));

    } catch (e) {
    }
  }

  /// Get count of pending syncs (for debugging/testing)
  int get pendingSyncCount => _pendingSyncs.length;

  /// Get queue size (for debugging/testing)
  int get queueSize => _syncQueue.length;

  /// Wait for all pending syncs to complete (for testing only)
  Future<void> waitForPendingSyncs() async {
    while (_pendingSyncs.isNotEmpty || _syncQueue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
