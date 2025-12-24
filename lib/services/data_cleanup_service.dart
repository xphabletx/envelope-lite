// lib/services/data_cleanup_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility service to find and clean up orphaned data
class DataCleanupService {
  final FirebaseFirestore _db;
  final String _userId;

  DataCleanupService(this._db, this._userId);

  /// Find scheduled payments with null or invalid envelope/group IDs
  Future<List<String>> findOrphanedScheduledPayments() async {
    final orphanedIds = <String>[];

    final paymentsSnapshot = await _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('scheduledPayments')
        .get();

    final envelopeIds = await _getValidEnvelopeIds();
    final groupIds = await _getValidGroupIds();

    for (final doc in paymentsSnapshot.docs) {
      final data = doc.data();
      final envelopeId = data['envelopeId'];
      final groupId = data['groupId'];

      // Payment must have EITHER envelope or group
      if (envelopeId == null && groupId == null) {
        orphanedIds.add(doc.id);
        debugPrint('Orphaned payment (no target): ${data['name']}');
        continue;
      }

      // If has envelope, check it exists
      if (envelopeId != null && !envelopeIds.contains(envelopeId)) {
        orphanedIds.add(doc.id);
        debugPrint('Orphaned payment (deleted envelope): ${data['name']}');
        continue;
      }

      // If has group, check it exists
      if (groupId != null && !groupIds.contains(groupId)) {
        orphanedIds.add(doc.id);
        debugPrint('Orphaned payment (deleted group): ${data['name']}');
        continue;
      }
    }

    return orphanedIds;
  }

  /// Delete all orphaned scheduled payments
  Future<int> cleanupOrphanedScheduledPayments() async {
    final orphanedIds = await findOrphanedScheduledPayments();

    if (orphanedIds.isEmpty) return 0;

    final batch = _db.batch();
    for (final id in orphanedIds) {
      batch.delete(
        _db
            .collection('users')
            .doc(_userId)
            .collection('solo')
            .doc('data')
            .collection('scheduledPayments')
            .doc(id),
      );
    }

    await batch.commit();
    debugPrint('Cleaned up ${orphanedIds.length} orphaned scheduled payments');
    return orphanedIds.length;
  }

  /// Find transactions for deleted envelopes
  Future<List<String>> findOrphanedTransactions() async {
    final orphanedIds = <String>[];

    final txSnapshot = await _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('transactions')
        .get();

    final envelopeIds = await _getValidEnvelopeIds();

    for (final doc in txSnapshot.docs) {
      final envelopeId = doc.data()['envelopeId'];
      if (envelopeId != null && !envelopeIds.contains(envelopeId)) {
        orphanedIds.add(doc.id);
        debugPrint('Orphaned transaction: ${doc.data()['description']}');
      }
    }

    return orphanedIds;
  }

  /// Delete all orphaned transactions
  Future<int> cleanupOrphanedTransactions() async {
    final orphanedIds = await findOrphanedTransactions();

    if (orphanedIds.isEmpty) return 0;

    final batch = _db.batch();
    for (final id in orphanedIds) {
      batch.delete(
        _db
            .collection('users')
            .doc(_userId)
            .collection('solo')
            .doc('data')
            .collection('transactions')
            .doc(id),
      );
    }

    await batch.commit();
    debugPrint('Cleaned up ${orphanedIds.length} orphaned transactions');
    return orphanedIds.length;
  }

  /// Clean up all orphaned data (transactions and scheduled payments)
  Future<Map<String, int>> cleanupAll() async {
    final paymentsDeleted = await cleanupOrphanedScheduledPayments();
    final txDeleted = await cleanupOrphanedTransactions();

    return {
      'payments': paymentsDeleted,
      'transactions': txDeleted,
    };
  }

  // Helper methods
  Future<Set<String>> _getValidEnvelopeIds() async {
    final snapshot = await _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('envelopes')
        .get();

    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<Set<String>> _getValidGroupIds() async {
    final snapshot = await _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('groups')
        .get();

    return snapshot.docs.map((doc) => doc.id).toSet();
  }
}
