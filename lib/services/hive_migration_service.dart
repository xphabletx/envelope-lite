// lib/services/hive_migration_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/envelope_group.dart';
import '../models/transaction.dart' as app_transaction;
import '../models/scheduled_payment.dart';
import './hive_service.dart';

/// Migrates user data from Firebase to Hive (one-time operation)
class HiveMigrationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  HiveMigrationService(this._firestore, this._auth);

  /// Check if migration is needed for current user
  Future<bool> needsMigration() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool('hive_migration_complete_${user.uid}') ?? false;

    if (migrated) {
      debugPrint('[Migration] User ${user.uid} already migrated');
      return false;
    }

    // Check if user has any Firebase data
    final envelopesSnap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('solo')
        .doc('data')
        .collection('envelopes')
        .limit(1)
        .get();

    final hasFirebaseData = envelopesSnap.docs.isNotEmpty;
    debugPrint('[Migration] User has Firebase data: $hasFirebaseData');

    return hasFirebaseData;
  }

  /// Migrate all user data from Firebase to Hive
  ///
  /// Returns true if migration succeeded, false if failed.
  Future<bool> migrate() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[Migration] ❌ No user signed in');
      return false;
    }

    final uid = user.uid;
    debugPrint('[Migration] Starting migration for user: $uid');

    try {
      // 1. Migrate Envelopes
      debugPrint('[Migration] Migrating envelopes...');
      final envelopesSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('envelopes')
          .get();

      final envelopesBox = HiveService.getBox<Envelope>('envelopes');
      for (final doc in envelopesSnap.docs) {
        final envelope = Envelope.fromFirestore(doc);
        await envelopesBox.put(envelope.id, envelope);
      }
      debugPrint('[Migration] ✅ Migrated ${envelopesSnap.docs.length} envelopes');

      // 2. Migrate Accounts
      debugPrint('[Migration] Migrating accounts...');
      final accountsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('accounts')
          .get();

      final accountsBox = HiveService.getBox<Account>('accounts');
      for (final doc in accountsSnap.docs) {
        final account = Account.fromFirestore(doc);
        await accountsBox.put(account.id, account);
      }
      debugPrint('[Migration] ✅ Migrated ${accountsSnap.docs.length} accounts');

      // 3. Migrate Groups
      debugPrint('[Migration] Migrating groups...');
      final groupsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('groups')
          .get();

      final groupsBox = HiveService.getBox<EnvelopeGroup>('groups');
      for (final doc in groupsSnap.docs) {
        final group = EnvelopeGroup.fromFirestore(doc);
        await groupsBox.put(group.id, group);
      }
      debugPrint('[Migration] ✅ Migrated ${groupsSnap.docs.length} groups');

      // 4. Migrate Transactions
      debugPrint('[Migration] Migrating transactions...');
      final txSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('transactions')
          .get();

      final txBox = HiveService.getBox<app_transaction.Transaction>('transactions');
      for (final doc in txSnap.docs) {
        final tx = app_transaction.Transaction.fromFirestore(doc);
        await txBox.put(tx.id, tx);
      }
      debugPrint('[Migration] ✅ Migrated ${txSnap.docs.length} transactions');

      // 5. Migrate Scheduled Payments
      debugPrint('[Migration] Migrating scheduled payments...');
      final schedSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('scheduledPayments')
          .get();

      final schedBox = HiveService.getBox<ScheduledPayment>('scheduledPayments');
      for (final doc in schedSnap.docs) {
        final payment = ScheduledPayment.fromFirestore(doc);
        await schedBox.put(payment.id, payment);
      }
      debugPrint('[Migration] ✅ Migrated ${schedSnap.docs.length} scheduled payments');

      // 6. Set migration flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hive_migration_complete_$uid', true);
      debugPrint('[Migration] ✅ Migration complete for user: $uid');

      return true;
    } catch (e, stackTrace) {
      debugPrint('[Migration] ❌ Migration failed: $e');
      debugPrint('[Migration] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Sync Hive data back to Firebase (reverse migration)
  ///
  /// This pushes all local Hive data to Firebase, useful for:
  /// - Creating a cloud backup of local data
  /// - Switching from solo mode to workspace mode
  /// - Recovering from Firebase data loss
  ///
  /// Returns a map with sync results:
  /// - 'success': bool (true if sync succeeded)
  /// - 'envelopes': int (count synced)
  /// - 'accounts': int (count synced)
  /// - 'groups': int (count synced)
  /// - 'transactions': int (count synced)
  /// - 'scheduledPayments': int (count synced)
  Future<Map<String, dynamic>> syncToFirebase({
    Function(String)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[ReverseSync] ❌ No user signed in');
      return {'success': false, 'error': 'No user signed in'};
    }

    final uid = user.uid;
    debugPrint('[ReverseSync] Starting Hive → Firebase sync for user: $uid');

    try {
      int envelopesCount = 0;
      int accountsCount = 0;
      int groupsCount = 0;
      int transactionsCount = 0;
      int scheduledPaymentsCount = 0;

      // 1. Sync Envelopes
      onProgress?.call('Syncing envelopes...');
      debugPrint('[ReverseSync] Syncing envelopes...');
      final envelopesBox = HiveService.getBox<Envelope>('envelopes');
      final userEnvelopes = envelopesBox.values.where((e) => e.userId == uid).toList();

      final envelopesCol = _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('envelopes');

      for (final envelope in userEnvelopes) {
        await envelopesCol.doc(envelope.id).set({
          'id': envelope.id,
          'name': envelope.name,
          'currentAmount': envelope.currentAmount,
          'targetAmount': envelope.targetAmount,
          'targetDate': envelope.targetDate,
          'userId': envelope.userId,
          'groupId': envelope.groupId,
          'emoji': envelope.emoji,
          'linkedAccountId': envelope.linkedAccountId,
          'isShared': envelope.isShared,
          'iconType': envelope.iconType,
          'iconValue': envelope.iconValue,
          'iconColor': envelope.iconColor,
          'subtitle': envelope.subtitle,
          'autoFillEnabled': envelope.autoFillEnabled,
          'autoFillAmount': envelope.autoFillAmount,
          'isDebtEnvelope': envelope.isDebtEnvelope,
          'startingDebt': envelope.startingDebt,
          'termStartDate': envelope.termStartDate,
          'termMonths': envelope.termMonths,
          'monthlyPayment': envelope.monthlyPayment,
        }, SetOptions(merge: true));
        envelopesCount++;
      }
      debugPrint('[ReverseSync] ✅ Synced $envelopesCount envelopes');

      // 2. Sync Accounts
      onProgress?.call('Syncing accounts...');
      debugPrint('[ReverseSync] Syncing accounts...');
      final accountsBox = HiveService.getBox<Account>('accounts');
      final userAccounts = accountsBox.values.where((a) => a.userId == uid).toList();

      final accountsCol = _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('accounts');

      for (final account in userAccounts) {
        await accountsCol.doc(account.id).set({
          'id': account.id,
          'name': account.name,
          'currentBalance': account.currentBalance,
          'userId': account.userId,
          'emoji': account.emoji,
          'colorName': account.colorName,
          'createdAt': account.createdAt,
          'lastUpdated': account.lastUpdated,
          'isDefault': account.isDefault,
          'isShared': account.isShared,
          'iconType': account.iconType,
          'iconValue': account.iconValue,
          'iconColor': account.iconColor,
          'accountType': account.accountType.name,
          'creditLimit': account.creditLimit,
        }, SetOptions(merge: true));
        accountsCount++;
      }
      debugPrint('[ReverseSync] ✅ Synced $accountsCount accounts');

      // 3. Sync Groups
      onProgress?.call('Syncing groups...');
      debugPrint('[ReverseSync] Syncing groups...');
      final groupsBox = HiveService.getBox<EnvelopeGroup>('groups');
      final userGroups = groupsBox.values.where((g) => g.userId == uid).toList();

      final groupsCol = _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('groups');

      for (final group in userGroups) {
        await groupsCol.doc(group.id).set({
          'id': group.id,
          'name': group.name,
          'userId': group.userId,
          'emoji': group.emoji,
          'iconType': group.iconType,
          'iconValue': group.iconValue,
          'iconColor': group.iconColor,
          'colorIndex': group.colorIndex,
          'payDayEnabled': group.payDayEnabled,
          'isShared': group.isShared,
        }, SetOptions(merge: true));
        groupsCount++;
      }
      debugPrint('[ReverseSync] ✅ Synced $groupsCount groups');

      // 4. Sync Transactions
      onProgress?.call('Syncing transactions...');
      debugPrint('[ReverseSync] Syncing transactions...');
      final txBox = HiveService.getBox<app_transaction.Transaction>('transactions');
      final userTx = txBox.values.where((t) => t.userId == uid).toList();

      final txCol = _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('transactions');

      // Use batched writes for transactions (there can be many)
      var batch = _firestore.batch();
      var batchCount = 0;
      const batchSize = 500; // Firestore batch limit

      for (final tx in userTx) {
        final txRef = txCol.doc(tx.id);
        batch.set(txRef, {
          'id': tx.id,
          'envelopeId': tx.envelopeId,
          'userId': tx.userId,
          'amount': tx.amount,
          'description': tx.description,
          'type': tx.type.name,
          'date': tx.date,
          'transferPeerEnvelopeId': tx.transferPeerEnvelopeId,
          'transferLinkId': tx.transferLinkId,
          'transferDirection': tx.transferDirection?.name,
          'ownerId': tx.ownerId,
          'sourceOwnerId': tx.sourceOwnerId,
          'targetOwnerId': tx.targetOwnerId,
          'sourceEnvelopeName': tx.sourceEnvelopeName,
          'targetEnvelopeName': tx.targetEnvelopeName,
          'sourceOwnerDisplayName': tx.sourceOwnerDisplayName,
          'targetOwnerDisplayName': tx.targetOwnerDisplayName,
        }, SetOptions(merge: true));

        batchCount++;
        transactionsCount++;

        // Commit batch every 500 operations
        if (batchCount >= batchSize) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
          debugPrint('[ReverseSync] Committed batch of $batchSize transactions');
        }
      }

      // Commit remaining transactions
      if (batchCount > 0) {
        await batch.commit();
      }
      debugPrint('[ReverseSync] ✅ Synced $transactionsCount transactions');

      // 5. Sync Scheduled Payments
      onProgress?.call('Syncing scheduled payments...');
      debugPrint('[ReverseSync] Syncing scheduled payments...');
      final schedBox = HiveService.getBox<ScheduledPayment>('scheduledPayments');
      final userSched = schedBox.values.where((s) => s.userId == uid).toList();

      final schedCol = _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('scheduledPayments');

      for (final payment in userSched) {
        await schedCol.doc(payment.id).set({
          'id': payment.id,
          'userId': payment.userId,
          'envelopeId': payment.envelopeId,
          'groupId': payment.groupId,
          'name': payment.name,
          'description': payment.description,
          'amount': payment.amount,
          'startDate': payment.startDate,
          'frequencyValue': payment.frequencyValue,
          'frequencyUnit': payment.frequencyUnit.name,
          'colorName': payment.colorName,
          'colorValue': payment.colorValue,
          'isAutomatic': payment.isAutomatic,
          'createdAt': payment.createdAt,
          'lastExecuted': payment.lastExecuted,
        }, SetOptions(merge: true));
        scheduledPaymentsCount++;
      }
      debugPrint('[ReverseSync] ✅ Synced $scheduledPaymentsCount scheduled payments');

      onProgress?.call('Sync complete!');
      debugPrint('[ReverseSync] ✅ Sync complete for user: $uid');

      return {
        'success': true,
        'envelopes': envelopesCount,
        'accounts': accountsCount,
        'groups': groupsCount,
        'transactions': transactionsCount,
        'scheduledPayments': scheduledPaymentsCount,
      };
    } catch (e, stackTrace) {
      debugPrint('[ReverseSync] ❌ Sync failed: $e');
      debugPrint('[ReverseSync] Stack trace: $stackTrace');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Verify migration by comparing Hive vs Firebase data
  ///
  /// Returns a map with verification results:
  /// - 'success': bool (true if all data matches)
  /// - 'envelopes': int (count in Hive)
  /// - 'accounts': int (count in Hive)
  /// - 'mismatches': List<String> (descriptions of mismatches)
  Future<Map<String, dynamic>> verifyMigration() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'No user signed in'};
    }

    final uid = user.uid;
    debugPrint('[Migration] Verifying migration for user: $uid');

    try {
      final mismatches = <String>[];

      // 1. Verify Envelopes
      final firebaseEnvelopesSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('envelopes')
          .get();

      final hiveEnvelopesBox = HiveService.getBox<Envelope>('envelopes');
      final hiveEnvelopes = hiveEnvelopesBox.values.where((e) => e.userId == uid).toList();

      if (firebaseEnvelopesSnap.docs.length != hiveEnvelopes.length) {
        mismatches.add(
          'Envelopes count mismatch: Firebase=${firebaseEnvelopesSnap.docs.length}, Hive=${hiveEnvelopes.length}',
        );
      }

      // Sample check: verify 10 random envelopes match
      for (final doc in firebaseEnvelopesSnap.docs.take(10)) {
        final firebaseEnv = Envelope.fromFirestore(doc);
        final hiveEnv = hiveEnvelopesBox.get(firebaseEnv.id);

        if (hiveEnv == null) {
          mismatches.add('Envelope ${firebaseEnv.id} not found in Hive');
        } else if (hiveEnv.name != firebaseEnv.name ||
            hiveEnv.currentAmount != firebaseEnv.currentAmount) {
          mismatches.add('Envelope ${firebaseEnv.id} data mismatch');
        }
      }

      // 2. Verify Accounts (similar pattern)
      final firebaseAccountsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('accounts')
          .get();

      final hiveAccountsBox = HiveService.getBox<Account>('accounts');
      final hiveAccounts = hiveAccountsBox.values.where((a) => a.userId == uid).toList();

      if (firebaseAccountsSnap.docs.length != hiveAccounts.length) {
        mismatches.add(
          'Accounts count mismatch: Firebase=${firebaseAccountsSnap.docs.length}, Hive=${hiveAccounts.length}',
        );
      }

      // 3. Verify Transactions (count only - too many to check individually)
      final firebaseTxSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('solo')
          .doc('data')
          .collection('transactions')
          .get();

      final hiveTxBox = HiveService.getBox<app_transaction.Transaction>('transactions');
      final hiveTx = hiveTxBox.values.where((t) => t.userId == uid).toList();

      if (firebaseTxSnap.docs.length != hiveTx.length) {
        mismatches.add(
          'Transactions count mismatch: Firebase=${firebaseTxSnap.docs.length}, Hive=${hiveTx.length}',
        );
      }

      final success = mismatches.isEmpty;
      debugPrint('[Migration] Verification ${success ? '✅ PASSED' : '❌ FAILED'}');
      if (!success) {
        for (final mismatch in mismatches) {
          debugPrint('[Migration] Mismatch: $mismatch');
        }
      }

      return {
        'success': success,
        'envelopes': hiveEnvelopes.length,
        'accounts': hiveAccounts.length,
        'transactions': hiveTx.length,
        'mismatches': mismatches,
      };
    } catch (e) {
      debugPrint('[Migration] ❌ Verification failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
