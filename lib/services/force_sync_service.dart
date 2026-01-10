// lib/services/force_sync_service.dart
// Force sync all local Hive data to Firebase
// Use this to recover from sync failures or data divergence

import 'package:hive/hive.dart';
import '../models/envelope.dart';
import '../models/envelope_group.dart';
import '../models/account.dart';
import '../models/scheduled_payment.dart';
import '../models/transaction.dart' as model;
import 'sync_manager.dart';

/// Force sync all local Hive data to Firebase
///
/// Use cases:
/// - Recovering from sync queue loss (e.g., persistence was disabled)
/// - Manual data backup to cloud
/// - Resolving data divergence issues
class ForceSyncService {
  final SyncManager _syncManager = SyncManager();

  /// Force sync all local data to Firebase for a specific user
  Future<ForceSyncResult> forceSyncAll({
    required String userId,
    String? workspaceId,
  }) async {
    final result = ForceSyncResult();

    try {
      // 1. Sync all envelopes
      final envelopeBox = Hive.box<Envelope>('envelopes');
      final userEnvelopes = envelopeBox.values.where((e) => e.userId == userId).toList();

      for (final envelope in userEnvelopes) {
        _syncManager.pushEnvelope(envelope, workspaceId, userId);
        result.envelopesSynced++;
      }

      // 2. Sync all groups (binders)
      final groupBox = Hive.box<EnvelopeGroup>('groups');
      final userGroups = groupBox.values.where((g) => g.userId == userId).toList();

      for (final group in userGroups) {
        _syncManager.pushGroup(group, userId);
        result.groupsSynced++;
      }

      // 3. Sync all accounts
      final accountBox = Hive.box<Account>('accounts');
      final userAccounts = accountBox.values.where((a) => a.userId == userId).toList();

      for (final account in userAccounts) {
        _syncManager.pushAccount(account, userId);
        result.accountsSynced++;
      }

      // 4. Sync all transactions
      final transactionBox = Hive.box<model.Transaction>('transactions');
      final userTransactions = transactionBox.values.where((t) => t.userId == userId).toList();

      for (final transaction in userTransactions) {
        // Check if this is a partner transfer (for workspace mode)
        final isPartnerTransfer = workspaceId != null &&
            transaction.type == model.TransactionType.transfer &&
            transaction.sourceOwnerId != null &&
            transaction.targetOwnerId != null &&
            transaction.sourceOwnerId != transaction.targetOwnerId;

        _syncManager.pushTransaction(transaction, workspaceId, userId, isPartnerTransfer);
        result.transactionsSynced++;
      }

      // 5. Sync all scheduled payments
      final scheduledPaymentBox = Hive.box<ScheduledPayment>('scheduledPayments');
      final userPayments = scheduledPaymentBox.values.where((p) => p.userId == userId).toList();

      for (final payment in userPayments) {
        _syncManager.pushScheduledPayment(payment, userId);
        result.scheduledPaymentsSynced++;
      }

      result.success = true;

      return result;
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Wait for all pending syncs to complete
  Future<void> waitForCompletion() async {
    await _syncManager.waitForPendingSyncs();
  }
}

/// Result of force sync operation
class ForceSyncResult {
  bool success = false;
  String? error;
  int envelopesSynced = 0;
  int groupsSynced = 0;
  int accountsSynced = 0;
  int transactionsSynced = 0;
  int scheduledPaymentsSynced = 0;

  int get totalItemsSynced =>
      envelopesSynced +
      groupsSynced +
      accountsSynced +
      transactionsSynced +
      scheduledPaymentsSynced;
}
