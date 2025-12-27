// lib/services/account_repo.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/envelope.dart';
import 'envelope_repo.dart';
import 'hive_service.dart';

class AccountRepo {
  AccountRepo(this._db, this._envelopeRepo) {
    // Initialize Hive box
    _accountBox = HiveService.getBox<Account>('accounts');
  }

  final fs.FirebaseFirestore _db;
  final EnvelopeRepo _envelopeRepo;
  late final Box<Account> _accountBox;

  String get _userId => _envelopeRepo.currentUserId;
  bool get _inWorkspace => _envelopeRepo.inWorkspace;
  String? get _workspaceId => _envelopeRepo.workspaceId;

  // --------- Collection References ----------

  fs.CollectionReference<Map<String, dynamic>> _accountsCol() {
    // Always use the user's solo collection for accounts
    // In workspace mode, accounts are shared via isShared field
    return _db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('accounts');
  }

  // --------- Streams ----------

  Stream<List<Account>> accountsStream() {
    if (!_inWorkspace) {
      // Solo mode: Use Hive's watch() stream (only emits when data changes)
      debugPrint('[AccountRepo] 📦 Setting up Hive stream (solo mode)');

      // Emit initial state immediately
      final initialAccounts = _accountBox.values
          .where((account) => account.userId == _userId)
          .toList();
      debugPrint('[AccountRepo] ✅ Initial state: ${initialAccounts.length} accounts from Hive');

      // Then listen for changes
      return Stream.value(initialAccounts).asBroadcastStream().concatWith([
        _accountBox.watch().map((_) {
          final accounts = _accountBox.values
              .where((account) => account.userId == _userId)
              .toList();
          debugPrint('[AccountRepo] ✅ Emitting ${accounts.length} accounts from Hive');
          return accounts;
        })
      ]);
    }

    // For workspace mode, read from all members' solo accounts (filtered by isShared)
    return _db.collection('workspaces').doc(_workspaceId).snapshots().asyncMap(
      (workspaceSnap) async {
        if (!workspaceSnap.exists) return <Account>[];

        final workspaceData = workspaceSnap.data();
        final members = (workspaceData?['members'] as Map<String, dynamic>?) ?? {};

        if (!members.containsKey(_userId)) {
          return <Account>[];
        }

        if (members.isEmpty) return <Account>[];

        final List<Account> allAccounts = [];

        for (final memberId in members.keys) {
          final memberAccountsSnap = await _db
              .collection('users')
              .doc(memberId)
              .collection('solo')
              .doc('data')
              .collection('accounts')
              .orderBy('createdAt', descending: false)
              .get();

          for (final doc in memberAccountsSnap.docs) {
            final account = Account.fromFirestore(doc);
            // Show own accounts or shared accounts from others
            if (account.userId == _userId || account.isShared) {
              allAccounts.add(account);
            }
          }
        }

        return allAccounts;
      },
    );
  }

  Stream<Account> accountStream(String accountId) {
    return _accountsCol()
        .doc(accountId)
        .snapshots()
        .map((doc) => Account.fromFirestore(doc));
  }

  // --------- CRUD Operations ----------

  Future<String> createAccount({
    required String name,
    required double startingBalance,
    String? emoji,
    String? colorName,
    bool isDefault = false,
    String? iconType,
    String? iconValue,
    int? iconColor,
    AccountType accountType = AccountType.bankAccount,
    double? creditLimit,
  }) async {
    final doc = _accountsCol().doc();

    if (isDefault) {
      await _unsetOtherDefaults();
    }

    // Create Account object
    final now = DateTime.now();
    final account = Account(
      id: doc.id,
      name: name,
      currentBalance: startingBalance,
      userId: _userId,
      emoji: emoji,
      colorName: colorName,
      createdAt: now,
      lastUpdated: now,
      isDefault: isDefault,
      isShared: _inWorkspace,
      iconType: iconType,
      iconValue: iconValue,
      iconColor: iconColor,
      accountType: accountType,
      creditLimit: creditLimit,
    );

    // ALWAYS write to Hive
    await _accountBox.put(doc.id, account);
    debugPrint('[AccountRepo] ✅ Account saved to Hive: ${doc.id}');

    // ONLY write to Firebase if in workspace mode
    if (_inWorkspace) {
      await doc.set({
        'id': doc.id,
        'name': name,
        'currentBalance': startingBalance,
        'userId': _userId,
        'emoji': emoji,
        'colorName': colorName,
        'createdAt': fs.FieldValue.serverTimestamp(),
        'lastUpdated': fs.FieldValue.serverTimestamp(),
        'isDefault': isDefault,
        'isShared': _inWorkspace,
        'workspaceId': _workspaceId,
        'iconType': iconType,
        'iconValue': iconValue,
        'iconColor': iconColor,
        'accountType': accountType.name,
        'creditLimit': creditLimit,
      });
      debugPrint('[AccountRepo] ✅ Account synced to Firebase workspace');
    } else {
      debugPrint('[AccountRepo] ⏭️ Skipping Firebase (solo mode)');
    }

    return doc.id;
  }

  Future<void> updateAccount({
    required String accountId,
    String? name,
    double? currentBalance,
    String? emoji,
    String? colorName,
    bool? isDefault,
    String? iconType,
    String? iconValue,
    int? iconColor,
  }) async {
    // DEBUG: Check workspace status
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('active_workspace_id');

    debugPrint('[AccountRepo] DEBUG UPDATE:');
    debugPrint('  - Account ID: $accountId');
    debugPrint('  - WorkspaceId from prefs: ${workspaceId ?? "NULL"}');
    debugPrint('  - _inWorkspace flag: $_inWorkspace');

    // Get current account from Hive
    final account = _accountBox.get(accountId);
    if (account == null) {
      debugPrint('[AccountRepo] ❌ Account not found in Hive: $accountId');
      throw Exception('Account not found: $accountId');
    }

    if (isDefault == true) {
      await _unsetOtherDefaults(excludeAccountId: accountId);
    }

    // Create updated account
    final updatedAccount = Account(
      id: account.id,
      name: name ?? account.name,
      currentBalance: currentBalance ?? account.currentBalance,
      userId: account.userId,
      emoji: emoji ?? account.emoji,
      colorName: colorName ?? account.colorName,
      createdAt: account.createdAt,
      lastUpdated: DateTime.now(),
      isDefault: isDefault ?? account.isDefault,
      isShared: account.isShared,
      iconType: iconType ?? account.iconType,
      iconValue: iconValue ?? account.iconValue,
      iconColor: iconColor ?? account.iconColor,
      accountType: account.accountType,
      creditLimit: account.creditLimit,
    );

    // ALWAYS write to Hive
    await _accountBox.put(accountId, updatedAccount);
    debugPrint('[AccountRepo] ✅ Account updated in Hive: $accountId');

    // Check Firebase sync
    if (_inWorkspace && workspaceId != null) {
      debugPrint('[AccountRepo] 🔥 Syncing to Firebase workspace: $workspaceId');
      try {
        final updateData = <String, dynamic>{
          'lastUpdated': fs.FieldValue.serverTimestamp(),
        };

        if (name != null) updateData['name'] = name;
        if (currentBalance != null) updateData['currentBalance'] = currentBalance;
        if (emoji != null) updateData['emoji'] = emoji;
        if (colorName != null) updateData['colorName'] = colorName;
        if (iconType != null) {
          updateData['iconType'] = iconType;
          updateData['iconValue'] = iconValue;
          updateData['iconColor'] = iconColor;
        }

        if (isDefault == true) {
          updateData['isDefault'] = true;
        } else if (isDefault == false) {
          updateData['isDefault'] = false;
        }

        await _accountsCol().doc(accountId).update(updateData);
        debugPrint('[AccountRepo] ✅ Firebase sync successful');
      } catch (e) {
        debugPrint('[AccountRepo] ❌ Firebase sync failed: $e');
      }
    } else if (_inWorkspace && workspaceId == null) {
      debugPrint('[AccountRepo] ⚠️ _inWorkspace is TRUE but workspaceId is NULL!');
      debugPrint('[AccountRepo] ⚠️ This is a bug - EnvelopeRepo workspace status is stale');
    } else {
      debugPrint('[AccountRepo] ⏭️ Skipping Firebase (solo mode)');
    }
  }

  Future<void> deleteAccount(String accountId) async {
    // 1. Check for linked envelopes - prevent deletion if any exist
    final linkedEnvelopes = await getLinkedEnvelopes(accountId);

    if (linkedEnvelopes.isNotEmpty) {
      throw Exception(
        'Cannot delete account with linked envelopes. Please unlink or delete ${linkedEnvelopes.length} envelope(s) first.',
      );
    }

    // 2. Delete from Hive
    await _accountBox.delete(accountId);
    debugPrint('[AccountRepo] ✅ Account deleted from Hive: $accountId');

    // 3. If in workspace mode, also delete from Firebase
    if (_inWorkspace) {
      // Check PayDaySettings - if this is the default account, clear it
      final paySettingsRef = _db
          .collection('users')
          .doc(_userId)
          .collection('payDaySettings')
          .doc('settings');

      final paySettings = await paySettingsRef.get();
      if (paySettings.exists &&
          paySettings.data()?['defaultAccountId'] == accountId) {
        await paySettingsRef.update({
          'defaultAccountId': null,
          'updatedAt': fs.FieldValue.serverTimestamp(),
        });
      }

      // Delete the account
      await _accountsCol().doc(accountId).delete();
      debugPrint('[AccountRepo] ✅ Account deleted from Firebase workspace');
    }
  }

  Future<void> adjustBalance({
    required String accountId,
    required double amount,
  }) async {
    // Get current account from Hive
    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

    // Create updated account
    final updatedAccount = Account(
      id: account.id,
      name: account.name,
      currentBalance: account.currentBalance + amount,
      userId: account.userId,
      emoji: account.emoji,
      colorName: account.colorName,
      createdAt: account.createdAt,
      lastUpdated: DateTime.now(),
      isDefault: account.isDefault,
      isShared: account.isShared,
      iconType: account.iconType,
      iconValue: account.iconValue,
      iconColor: account.iconColor,
      accountType: account.accountType,
      creditLimit: account.creditLimit,
    );

    await _accountBox.put(accountId, updatedAccount);
    debugPrint('[AccountRepo] ✅ Balance adjusted in Hive: ${amount > 0 ? '+' : ''}\$$amount');

    if (_inWorkspace) {
      await _accountsCol().doc(accountId).update({
        'currentBalance': fs.FieldValue.increment(amount),
        'lastUpdated': fs.FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setBalance({
    required String accountId,
    required double newBalance,
  }) async {
    // Get current account from Hive
    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

    // Create updated account
    final updatedAccount = Account(
      id: account.id,
      name: account.name,
      currentBalance: newBalance,
      userId: account.userId,
      emoji: account.emoji,
      colorName: account.colorName,
      createdAt: account.createdAt,
      lastUpdated: DateTime.now(),
      isDefault: account.isDefault,
      isShared: account.isShared,
      iconType: account.iconType,
      iconValue: account.iconValue,
      iconColor: account.iconColor,
      accountType: account.accountType,
      creditLimit: account.creditLimit,
    );

    await _accountBox.put(accountId, updatedAccount);
    debugPrint('[AccountRepo] ✅ Balance set in Hive: \$$newBalance');

    if (_inWorkspace) {
      await _accountsCol().doc(accountId).update({
        'currentBalance': newBalance,
        'lastUpdated': fs.FieldValue.serverTimestamp(),
      });
    }
  }

  // --------- Helper Methods ----------

  Future<Account?> getDefaultAccount() async {
    final snapshot = await _accountsCol()
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return Account.fromFirestore(snapshot.docs.first);
  }

  Future<List<Envelope>> getLinkedEnvelopes(String accountId) async {
    final snapshot = await _envelopeRepo.db
        .collection('users')
        .doc(_userId)
        .collection('solo')
        .doc('data')
        .collection('envelopes')
        .where('linkedAccountId', isEqualTo: accountId)
        .get();

    return snapshot.docs.map((doc) => Envelope.fromFirestore(doc)).toList();
  }

  Future<double> getAssignedAmount(String accountId) async {
    final linkedEnvelopes = await getLinkedEnvelopes(accountId);
    double total = 0.0;
    for (final envelope in linkedEnvelopes) {
      total += envelope.currentAmount;
    }
    return total;
  }

  Future<double> getAvailableAmount(String accountId) async {
    final account = await _accountsCol().doc(accountId).get();
    if (!account.exists) return 0.0;

    final accountData = Account.fromFirestore(account);
    final assigned = await getAssignedAmount(accountId);

    return accountData.currentBalance - assigned;
  }

  Future<Account?> getAccount(String accountId) async {
    final doc = await _accountsCol().doc(accountId).get();
    if (!doc.exists) return null;
    return Account.fromFirestore(doc);
  }

  Future<List<Account>> getAllAccounts() async {
    final snapshot = await _accountsCol().orderBy('createdAt').get();
    return snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList();
  }

  // --------- Private Helpers ----------

  Future<void> _unsetOtherDefaults({String? excludeAccountId}) async {
    // Update Hive first
    final allAccounts = _accountBox.values.toList();
    for (final account in allAccounts) {
      if (account.isDefault && account.id != excludeAccountId) {
        final updated = Account(
          id: account.id,
          name: account.name,
          userId: account.userId,
          currentBalance: account.currentBalance,
          createdAt: account.createdAt,
          lastUpdated: DateTime.now(),
          iconType: account.iconType,
          iconValue: account.iconValue,
          iconColor: account.iconColor,
          isDefault: false,
          creditLimit: account.creditLimit,
          accountType: account.accountType,
          emoji: account.emoji,
          colorName: account.colorName,
          isShared: account.isShared,
          workspaceId: account.workspaceId,
        );
        await _accountBox.put(account.id, updated);
      }
    }
    debugPrint('[AccountRepo] ✅ Unset other defaults in Hive');

    // ONLY update Firebase if in workspace mode
    if (_inWorkspace) {
      final batch = _db.batch();

      final snapshot = await _accountsCol()
          .where('isDefault', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        if (excludeAccountId != null && doc.id == excludeAccountId) {
          continue;
        }
        batch.update(doc.reference, {
          'isDefault': false,
          'lastUpdated': fs.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('[AccountRepo] ✅ Unset other defaults synced to Firebase');
    } else {
      debugPrint('[AccountRepo] ⏭️ Skipping Firebase unset defaults (solo mode)');
    }
  }
}
