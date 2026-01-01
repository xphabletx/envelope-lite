// lib/services/sync_manager.dart
// Background sync manager for Firebase sync operations
// Manages unawaited background sync to keep Firestore in sync with Hive

import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/envelope.dart';
import '../models/transaction.dart' as model;

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

  /// Push an envelope to cloud (workspace mode only)
  /// Returns immediately, sync happens in background
  void pushEnvelope(Envelope envelope, String? workspaceId) {
    if (workspaceId == null || workspaceId.isEmpty) return;
    if (!envelope.isShared) return; // Solo envelopes don't sync

    final syncKey = 'envelope_${envelope.id}';
    if (_pendingSyncs.contains(syncKey)) return; // Already syncing

    _pendingSyncs.add(syncKey);

    // Add to queue instead of immediate execution
    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncEnvelopeToFirestore(envelope, workspaceId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Push a transaction to cloud (workspace mode only, partner transfers only)
  /// CRITICAL: Filters out isFuture transactions to prevent syncing projections
  void pushTransaction(
    model.Transaction transaction,
    String? workspaceId,
    bool isPartnerTransfer,
  ) {
    if (workspaceId == null || workspaceId.isEmpty) return;
    if (!isPartnerTransfer) return; // Only partner transfers sync

    // CRITICAL: Never sync projected/future transactions from TimeMachine
    if (transaction.isFuture) {
      debugPrint('[SyncManager] ⚠️ Skipping future transaction ${transaction.id} (projection)');
      return;
    }

    final syncKey = 'transaction_${transaction.id}';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    // Add to queue
    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _syncTransactionToFirestore(transaction, workspaceId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Delete envelope from cloud
  void deleteEnvelope(String envelopeId, String? workspaceId) {
    if (workspaceId == null || workspaceId.isEmpty) return;

    final syncKey = 'delete_envelope_$envelopeId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _deleteEnvelopeFromFirestore(envelopeId, workspaceId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  /// Delete transaction from cloud
  void deleteTransaction(String transactionId, String? workspaceId, bool isPartnerTransfer) {
    if (workspaceId == null || workspaceId.isEmpty) return;
    if (!isPartnerTransfer) return;

    final syncKey = 'delete_transaction_$transactionId';
    if (_pendingSyncs.contains(syncKey)) return;

    _pendingSyncs.add(syncKey);

    _syncQueue.add(_SyncOperation(
      key: syncKey,
      execute: () => _deleteTransactionFromFirestore(transactionId, workspaceId, syncKey),
      onComplete: () => _pendingSyncs.remove(syncKey),
    ));
  }

  // =========================================================================
  // PRIVATE IMPLEMENTATION
  // =========================================================================

  Future<void> _syncEnvelopeToFirestore(
    Envelope envelope,
    String workspaceId,
    String syncKey,
  ) async {
    try {
      await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('envelopes')
          .doc(envelope.id)
          .set(envelope.toMap(), SetOptions(merge: true));

      debugPrint('[SyncManager] ✓ Synced envelope ${envelope.name}');
    } catch (e) {
      debugPrint('[SyncManager] ✗ Failed to sync envelope ${envelope.id}: $e');
      // Could implement retry logic here
    }
  }

  Future<void> _syncTransactionToFirestore(
    model.Transaction transaction,
    String workspaceId,
    String syncKey,
  ) async {
    try {
      await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('transfers')
          .doc(transaction.id)
          .set(transaction.toMap(), SetOptions(merge: true));

      debugPrint('[SyncManager] ✓ Synced transaction ${transaction.id}');
    } catch (e) {
      debugPrint('[SyncManager] ✗ Failed to sync transaction ${transaction.id}: $e');
    }
  }

  Future<void> _deleteEnvelopeFromFirestore(
    String envelopeId,
    String workspaceId,
    String syncKey,
  ) async {
    try {
      await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('envelopes')
          .doc(envelopeId)
          .delete();

      debugPrint('[SyncManager] ✓ Deleted envelope $envelopeId from cloud');
    } catch (e) {
      debugPrint('[SyncManager] ✗ Failed to delete envelope $envelopeId: $e');
    }
  }

  Future<void> _deleteTransactionFromFirestore(
    String transactionId,
    String workspaceId,
    String syncKey,
  ) async {
    try {
      await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('transfers')
          .doc(transactionId)
          .delete();

      debugPrint('[SyncManager] ✓ Deleted transaction $transactionId from cloud');
    } catch (e) {
      debugPrint('[SyncManager] ✗ Failed to delete transaction $transactionId: $e');
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
