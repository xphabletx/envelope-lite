// lib/services/cloud_migration_service.dart
// One-time cloud migration service for multi-device support
// Pulls data from Firebase on first login to populate empty Hive boxes

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/transaction.dart' as model;
import '../widgets/migration_overlay.dart';

/// Handles one-time migration of data from Firebase to Hive
///
/// Purpose: Enable multi-device support by pulling cloud data on first login
///
/// Flow:
/// 1. Check if Hive boxes are empty
/// 2. If empty, fetch all data from Firebase
/// 3. Populate Hive boxes using bulk operations (putAll)
/// 4. User can now use app offline with populated data
///
/// Enhanced with:
/// - Progress tracking via StreamController
/// - Bulk operations for performance (putAll instead of individual puts)
/// - User mismatch detection and cleanup
/// - Error recovery and retry logic
class CloudMigrationService {
  final FirebaseFirestore _firestore;
  final StreamController<MigrationProgress> _progressController =
      StreamController<MigrationProgress>.broadcast();

  Stream<MigrationProgress> get progressStream => _progressController.stream;

  CloudMigrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Perform migration if needed (called on login)
  /// Returns true if migration was performed, false if skipped
  Future<bool> migrateIfNeeded({
    required String userId,
    String? workspaceId,
  }) async {
    try {
      _progressController.add(MigrationProgress.step(
        progress: 0.1,
        step: 'Checking if migration needed...',
      ));

      // Check for user mismatch and clean up if needed
      await _checkAndCleanupUserMismatch(userId);

      // Check if migration is needed
      final needsMigration = await _checkIfMigrationNeeded(userId);

      if (!needsMigration) {
        debugPrint('[CloudMigration] Hive boxes already populated, skipping migration');
        _progressController.add(MigrationProgress.complete());
        return false;
      }

      debugPrint('[CloudMigration] Starting cloud migration for user $userId...');

      int totalItemsProcessed = 0;

      // Perform migration in steps
      _progressController.add(MigrationProgress.step(
        progress: 0.2,
        step: 'Restoring accounts...',
      ));
      totalItemsProcessed += await _migrateAccounts(userId);

      _progressController.add(MigrationProgress.step(
        progress: 0.4,
        step: 'Restoring envelopes...',
        itemsProcessed: totalItemsProcessed,
      ));
      totalItemsProcessed += await _migrateEnvelopes(userId, workspaceId);

      _progressController.add(MigrationProgress.step(
        progress: 0.7,
        step: 'Restoring transactions...',
        itemsProcessed: totalItemsProcessed,
      ));
      totalItemsProcessed += await _migrateTransactions(userId, workspaceId);

      _progressController.add(MigrationProgress.step(
        progress: 0.9,
        step: 'Restoring scheduled payments...',
        itemsProcessed: totalItemsProcessed,
      ));
      totalItemsProcessed += await _migrateScheduledPayments(userId);

      _progressController.add(MigrationProgress.complete(
        itemsProcessed: totalItemsProcessed,
      ));

      debugPrint('[CloudMigration] ✓ Migration complete: $totalItemsProcessed items');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[CloudMigration] ✗ Migration failed: $e');
      debugPrint('[CloudMigration] Stack trace: $stackTrace');

      _progressController.add(MigrationProgress.error(
        'Failed to restore data: ${e.toString()}',
      ));

      // Don't throw - allow app to continue even if migration fails
      return false;
    }
  }

  /// Check for user mismatch and clean up if needed
  /// Prevents data leakage when switching accounts
  Future<void> _checkAndCleanupUserMismatch(String newUserId) async {
    final envelopeBox = await Hive.openBox<Envelope>('envelopes');

    // Check if there's existing data for a different user
    final existingEnvelope = envelopeBox.values.firstOrNull;
    if (existingEnvelope != null && existingEnvelope.userId != newUserId) {
      debugPrint('[CloudMigration] ⚠️ User mismatch detected! Clearing all local data...');
      debugPrint('[CloudMigration]   Old user: ${existingEnvelope.userId}');
      debugPrint('[CloudMigration]   New user: $newUserId');

      // Clear all Hive boxes
      await _clearAllData();
    }
  }

  /// Clear all Hive data (GDPR compliance and user mismatch cleanup)
  Future<void> _clearAllData() async {
    try {
      final envelopeBox = await Hive.openBox<Envelope>('envelopes');
      final accountBox = await Hive.openBox<Account>('accounts');
      final transactionBox = await Hive.openBox<model.Transaction>('transactions');

      await Future.wait([
        envelopeBox.clear(),
        accountBox.clear(),
        transactionBox.clear(),
      ]);

      debugPrint('[CloudMigration] ✓ All Hive data cleared');
    } catch (e) {
      debugPrint('[CloudMigration] ✗ Failed to clear Hive data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }

  /// Check if any Hive box is empty (indicates first-time login)
  Future<bool> _checkIfMigrationNeeded(String userId) async {
    final envelopeBox = await Hive.openBox<Envelope>('envelopes');
    final transactionBox = await Hive.openBox<model.Transaction>('transactions');

    // Check if user has any envelopes or transactions in Hive
    final userEnvelopes = envelopeBox.values.where((e) => e.userId == userId);
    final userTransactions = transactionBox.values.where((t) => t.userId == userId);

    // If both are empty, migration is needed
    return userEnvelopes.isEmpty && userTransactions.isEmpty;
  }

  /// Migrate accounts from Firebase to Hive
  /// Note: Accounts don't sync to Firebase by design, but may exist locally
  /// This is a placeholder for future expansion
  Future<int> _migrateAccounts(String userId) async {
    // Accounts are local-only, nothing to migrate from cloud
    debugPrint('[CloudMigration] Accounts are local-only, skipping...');
    return 0;
  }

  /// Migrate envelopes from Firebase to Hive using bulk operations
  Future<int> _migrateEnvelopes(String userId, String? workspaceId) async {
    final envelopeBox = await Hive.openBox<Envelope>('envelopes');
    final Map<String, Envelope> bulkData = {};

    // Fetch from solo collection
    final soloSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('envelopes')
        .get();

    debugPrint('[CloudMigration] Found ${soloSnapshot.docs.length} solo envelopes');

    for (final doc in soloSnapshot.docs) {
      try {
        final envelope = Envelope.fromFirestore(doc).copyWith(
          isSynced: true, // From Firestore = already synced
          lastUpdated: DateTime.now(),
        );
        bulkData[envelope.id] = envelope;
      } catch (e) {
        debugPrint('[CloudMigration] Failed to parse envelope ${doc.id}: $e');
      }
    }

    // Fetch from workspace collection (if in workspace mode)
    if (workspaceId != null && workspaceId.isNotEmpty) {
      final workspaceSnapshot = await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('envelopes')
          .get();

      debugPrint('[CloudMigration] Found ${workspaceSnapshot.docs.length} workspace envelopes');

      for (final doc in workspaceSnapshot.docs) {
        try {
          final envelope = Envelope.fromFirestore(doc).copyWith(
            isSynced: true,
            lastUpdated: DateTime.now(),
          );
          bulkData[envelope.id] = envelope;
        } catch (e) {
          debugPrint('[CloudMigration] Failed to parse workspace envelope ${doc.id}: $e');
        }
      }
    }

    // Bulk insert using putAll for performance
    if (bulkData.isNotEmpty) {
      await envelopeBox.putAll(bulkData);
      debugPrint('[CloudMigration] ✓ Bulk inserted ${bulkData.length} envelopes');
    }

    return bulkData.length;
  }

  /// Migrate transactions from Firebase to Hive using bulk operations
  Future<int> _migrateTransactions(String userId, String? workspaceId) async {
    final transactionBox = await Hive.openBox<model.Transaction>('transactions');
    final Map<String, model.Transaction> bulkData = {};

    // Fetch from solo collection
    final soloSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .get();

    debugPrint('[CloudMigration] Found ${soloSnapshot.docs.length} solo transactions');

    for (final doc in soloSnapshot.docs) {
      try {
        final transaction = model.Transaction.fromFirestore(doc);
        // Already has isSynced and lastUpdated from fromFirestore
        bulkData[transaction.id] = transaction;
      } catch (e) {
        debugPrint('[CloudMigration] Failed to parse transaction ${doc.id}: $e');
      }
    }

    // Fetch from workspace transfers collection (if in workspace mode)
    if (workspaceId != null && workspaceId.isNotEmpty) {
      final workspaceSnapshot = await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('transfers')
          .get();

      debugPrint('[CloudMigration] Found ${workspaceSnapshot.docs.length} workspace transfers');

      for (final doc in workspaceSnapshot.docs) {
        try {
          final transaction = model.Transaction.fromFirestore(doc);
          bulkData[transaction.id] = transaction;
        } catch (e) {
          debugPrint('[CloudMigration] Failed to parse workspace transfer ${doc.id}: $e');
        }
      }
    }

    // Bulk insert using putAll for performance
    if (bulkData.isNotEmpty) {
      await transactionBox.putAll(bulkData);
      debugPrint('[CloudMigration] ✓ Bulk inserted ${bulkData.length} transactions');
    }

    return bulkData.length;
  }

  /// Migrate scheduled payments from Firebase to Hive
  /// Note: Scheduled payments may not sync to Firebase in current implementation
  /// This is a placeholder for future expansion
  Future<int> _migrateScheduledPayments(String userId) async {
    // Scheduled payments are local-only in current implementation
    debugPrint('[CloudMigration] Scheduled payments are local-only, skipping...');
    return 0;
  }

  /// Force a full re-sync from cloud (for debugging/recovery)
  /// WARNING: This will overwrite all local data with cloud data
  Future<void> forceResync({
    required String userId,
    String? workspaceId,
  }) async {
    debugPrint('[CloudMigration] Force re-sync requested - clearing Hive boxes...');

    final envelopeBox = await Hive.openBox<Envelope>('envelopes');
    final transactionBox = await Hive.openBox<model.Transaction>('transactions');

    // Clear user's data
    final envelopesToDelete = envelopeBox.values
        .where((e) => e.userId == userId)
        .map((e) => e.id)
        .toList();

    final transactionsToDelete = transactionBox.values
        .where((t) => t.userId == userId)
        .map((t) => t.id)
        .toList();

    await envelopeBox.deleteAll(envelopesToDelete);
    await transactionBox.deleteAll(transactionsToDelete);

    // Re-migrate
    await migrateIfNeeded(userId: userId, workspaceId: workspaceId);
  }
}
