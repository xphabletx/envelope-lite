// lib/services/account_repo.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart';
import '../models/account.dart';
import '../models/envelope.dart';
import '../models/pay_day_settings.dart';
import 'envelope_repo.dart';
import 'hive_service.dart';
import 'sync_manager.dart';

/// Account repository - Syncs to Firebase for cloud backup
///
/// CRITICAL: Accounts MUST sync to prevent data loss on logout/login
/// Syncs to: /users/{userId}/accounts
class AccountRepo {
  AccountRepo(this._envelopeRepo) {
    _accountBox = HiveService.getBox<Account>('accounts');
  }

  final EnvelopeRepo _envelopeRepo;
  late final Box<Account> _accountBox;
  final SyncManager _syncManager = SyncManager();
  bool _disposed = false;

  String get _userId => _envelopeRepo.currentUserId;

  /// Dispose the repository
  ///
  /// Since AccountRepo is always local-only (no Firestore streams),
  /// this is a no-op but included for consistency
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
  }

  // ======================= STREAMS =======================

  /// Accounts stream (ALWAYS local only)
  Stream<List<Account>> accountsStream() {
    // GUARD: Return empty stream if user is not authenticated (during logout)
    if (FirebaseAuth.instance.currentUser == null) {
      return Stream.value([]);
    }

    final initial = _accountBox.values
        .where((account) => account.userId == _userId)
        .toList();

    // Use Stream.multi() to ensure initial value is reliably emitted
    return Stream<List<Account>>.multi((controller) {
      // Emit initial value immediately
      controller.add(initial);

      // Listen to box changes
      final subscription = _accountBox.watch().listen((_) {
        final accounts = _accountBox.values
            .where((account) => account.userId == _userId)
            .toList();
        controller.add(accounts);
      });

      // Clean up when stream is cancelled
      controller.onCancel = () {
        subscription.cancel();
      };
    });
  }

  /// Single account stream (for live updates)
  Stream<Account> accountStream(String accountId) {
    final initial = _accountBox.get(accountId);
    if (initial == null) {
      throw Exception('Account not found: $accountId');
    }

    return Stream.value(initial).asBroadcastStream().concatWith([
      _accountBox.watch(key: accountId).map((_) {
        final account = _accountBox.get(accountId);
        if (account == null) {
          throw Exception('Account not found: $accountId');
        }
        return account;
      })
    ]);
  }

  // ==================== SYNCHRONOUS DATA ACCESS ====================
  // These methods provide instant access to Hive data without streams
  // Used as initialData for StreamBuilders to eliminate UI lag

  /// Get all accounts synchronously from Hive
  List<Account> getAccountsSync() {
    return _accountBox.values
        .where((account) => account.userId == _userId)
        .toList();
  }

  /// Get single account synchronously from Hive
  Account? getAccountSync(String accountId) {
    return _accountBox.get(accountId);
  }

  /// Get default account synchronously
  Account? getDefaultAccountSync() {
    return _accountBox.values
        .where((account) => account.userId == _userId && account.isDefault)
        .firstOrNull;
  }

  // ======================= CRUD OPERATIONS =======================

  /// Create account
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
    if (isDefault) {
      await _unsetOtherDefaults();
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final account = Account(
      id: id,
      name: name,
      currentBalance: startingBalance,
      userId: _userId,
      emoji: emoji,
      colorName: colorName,
      createdAt: now,
      lastUpdated: now,
      isDefault: isDefault,
      isShared: false,
      iconType: iconType ?? 'assetImage',
      iconValue: iconValue ?? 'assets/default/stufficon.png',
      iconColor: iconColor,
      accountType: accountType,
      creditLimit: creditLimit,
    );

    await _accountBox.put(id, account);

    // CRITICAL: Sync to Firebase to prevent data loss
    _syncManager.pushAccount(account, _userId);

    return id;
  }

  /// Update account
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
    if (isDefault == true) {
      await _unsetOtherDefaults(excludeAccountId: accountId);
    }

    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

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

    await _accountBox.put(accountId, updatedAccount);

    // CRITICAL: Sync to Firebase to prevent data loss
    _syncManager.pushAccount(updatedAccount, _userId);
  }

  /// Delete account
  Future<void> deleteAccount(String accountId) async {
    debugPrint('[AccountRepo] ========== DELETING ACCOUNT ==========');
    debugPrint('[AccountRepo] Account ID: $accountId');
    debugPrint('[AccountRepo] User ID: $_userId');

    final account = _accountBox.get(accountId);
    if (account == null) {
      debugPrint('[AccountRepo] ERROR: Account not found in Hive: $accountId');
      throw Exception('Account not found: $accountId');
    }

    debugPrint('[AccountRepo] Found account in Hive: ${account.name} (isDefault: ${account.isDefault})');

    // Get linked envelopes and unlink them (don't delete them)
    final linkedEnvelopes = await getLinkedEnvelopes(accountId);
    debugPrint('[AccountRepo] Found ${linkedEnvelopes.length} linked envelopes');

    if (linkedEnvelopes.isNotEmpty) {
      debugPrint('[AccountRepo] Unlinking ${linkedEnvelopes.length} envelopes...');
      for (final envelope in linkedEnvelopes) {
        debugPrint('[AccountRepo]   Unlinking envelope: ${envelope.name} (${envelope.id})');
        await _envelopeRepo.updateEnvelope(
          envelopeId: envelope.id,
          linkedAccountId: null,
          updateLinkedAccountId: true,
        );
      }
      debugPrint('[AccountRepo] All envelopes unlinked successfully');
    }

    debugPrint('[AccountRepo] Deleting account from Hive...');
    await _accountBox.delete(accountId);
    debugPrint('[AccountRepo] Account deleted from Hive');

    // Verify deletion
    final verifyDeleted = _accountBox.get(accountId);
    if (verifyDeleted != null) {
      debugPrint('[AccountRepo] WARNING: Account still exists in Hive after deletion!');
    } else {
      debugPrint('[AccountRepo] Verified: Account no longer in Hive');
    }

    // CRITICAL: Sync deletion to Firebase to prevent data loss
    debugPrint('[AccountRepo] Syncing deletion to Firebase...');
    _syncManager.deleteAccount(accountId, _userId);
    debugPrint('[AccountRepo] Firebase sync initiated');

    // Check remaining accounts
    final remainingAccounts = getAccountsSync();
    debugPrint('[AccountRepo] Remaining accounts: ${remainingAccounts.length}');
    for (final acc in remainingAccounts) {
      debugPrint('[AccountRepo]   - ${acc.name} (isDefault: ${acc.isDefault})');
    }

    debugPrint('[AccountRepo] ========== DELETE COMPLETE ==========');
  }

  /// Adjust balance by a delta amount
  Future<void> adjustBalance({
    required String accountId,
    required double amount,
  }) async {
    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

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

    // CRITICAL: Sync to Firebase to prevent data loss
    _syncManager.pushAccount(updatedAccount, _userId);
  }

  /// Set balance to a specific amount
  Future<void> setBalance({
    required String accountId,
    required double newBalance,
  }) async {
    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

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

    // CRITICAL: Sync to Firebase to prevent data loss
    _syncManager.pushAccount(updatedAccount, _userId);
  }

  // ======================= HELPER METHODS =======================

  Future<Account?> getDefaultAccount() async {
    final accounts = _accountBox.values
        .where((account) => account.userId == _userId && account.isDefault)
        .toList();

    return accounts.isEmpty ? null : accounts.first;
  }

  Future<List<Envelope>> getLinkedEnvelopes(String accountId) async {
    final allEnvelopes = await _envelopeRepo.getAllEnvelopes();
    return allEnvelopes.where((env) => env.linkedAccountId == accountId).toList();
  }

  Future<double> getAssignedAmount(String accountId) async {
    final linkedEnvelopes = await getLinkedEnvelopes(accountId);

    double total = 0.0;
    for (final envelope in linkedEnvelopes) {
      // CRITICAL FIX: Use cashFlowAmount (what's ALLOCATED), not currentAmount (what's IN the envelope)
      // This shows how much of the account balance is committed to cash flow on next pay day
      if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
        total += envelope.cashFlowAmount!;
      }
    }

    return total;
  }

  /// Stream the assigned amount for an account (updates when envelopes change)
  Stream<double> assignedAmountStream(String accountId) {
    return _envelopeRepo.envelopesStream().map((envelopes) {
      final linkedEnvelopes = envelopes.where((env) => env.linkedAccountId == accountId).toList();

      double total = 0.0;
      for (final envelope in linkedEnvelopes) {
        if (envelope.cashFlowEnabled && envelope.cashFlowAmount != null) {
          total += envelope.cashFlowAmount!;
        }
      }

      return total;
    });
  }

  Future<double> getAvailableAmount(String accountId) async {
    final account = await getAccount(accountId);
    if (account == null) return 0.0;

    final assigned = await getAssignedAmount(accountId);
    return account.currentBalance - assigned;
  }

  Future<Account?> getAccount(String accountId) async {
    return _accountBox.get(accountId);
  }

  Future<List<Account>> getAllAccounts() async {
    return _accountBox.values
        .where((account) => account.userId == _userId)
        .toList();
  }

  // ======================= ACCOUNT TRANSACTIONS =======================
  // Note: Account transactions are now tracked at the account level only.
  // We removed the virtual envelope system that was creating phantom envelopes.


  /// Set an account as default (unset others)
  Future<void> setDefaultAccount(String accountId) async {
    await _unsetOtherDefaults(excludeAccountId: accountId);

    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

    final updatedAccount = account.copyWith(isDefault: true);
    await _accountBox.put(accountId, updatedAccount);

    // CRITICAL: Sync to Firebase
    _syncManager.pushAccount(updatedAccount, _userId);
  }

  /// Deposit into account
  Future<void> deposit(String accountId, double amount, {String? description}) async {
    final account = await getAccount(accountId);
    if (account == null) return;

    final updatedAccount = account.copyWith(
      currentBalance: account.currentBalance + amount,
      lastUpdated: DateTime.now(),
    );

    await _accountBox.put(accountId, updatedAccount);

    // CRITICAL: Sync to Firebase
    _syncManager.pushAccount(updatedAccount, _userId);
  }

  /// Withdraw from account
  Future<void> withdraw(String accountId, double amount, {String? description}) async {
    final account = await getAccount(accountId);
    if (account == null) return;

    final updatedAccount = account.copyWith(
      currentBalance: account.currentBalance - amount,
      lastUpdated: DateTime.now(),
    );

    await _accountBox.put(accountId, updatedAccount);

    // CRITICAL: Sync to Firebase
    _syncManager.pushAccount(updatedAccount, _userId);
  }

  /// Transfer between accounts
  Future<void> transfer(String fromId, String toId, double amount, {String? description}) async {
    await withdraw(fromId, amount, description: description ?? 'Transfer out');
    await deposit(toId, amount, description: description ?? 'Transfer in');
  }

  /// Handle first account creation (auto-set as default)
  Future<Account> createFirstAccount({
    required String name,
    required AccountType type,
    required double currentBalance,
    double? creditLimit,
    String? iconType,
    String? iconValue,
    int? iconColor,
  }) async {
    // Check if any accounts exist
    final existingAccounts = await getAllAccounts();
    final isFirstAccount = existingAccounts.isEmpty;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    final account = Account(
      id: id,
      name: name,
      currentBalance: currentBalance,
      userId: _userId,
      createdAt: now,
      lastUpdated: now,
      isDefault: isFirstAccount, // Auto-set as default if first
      accountType: type,
      creditLimit: creditLimit,
      iconType: iconType,
      iconValue: iconValue,
      iconColor: iconColor,
    );

    await _accountBox.put(id, account);

    // CRITICAL: Sync to Firebase
    _syncManager.pushAccount(account, _userId);

    // If this is the first account, trigger transition to Account Mirror Mode
    if (isFirstAccount) {
      await _handleTransitionToAccountMode(account);
    }

    return account;
  }

  /// Transition from Budget Mode to Account Mirror Mode
  Future<void> _handleTransitionToAccountMode(Account defaultAccount) async {
    // 1. Update PayDaySettings with default account
    final payDaySettingsBox = Hive.box<PayDaySettings>('payDaySettings');
    final settings = payDaySettingsBox.get(_userId);

    if (settings != null) {
      final updatedSettings = settings.copyWith(
        defaultAccountId: defaultAccount.id,
      );
      await payDaySettingsBox.put(_userId, updatedSettings);

      // CRITICAL: Sync to Firebase
      _syncManager.pushPayDaySettings(updatedSettings, _userId);
    }

    // 2. Auto-link all envelopes with cash flow enabled
    final unlinkedEnvelopes = await _envelopeRepo.getUnlinkedCashFlowEnvelopes();

    if (unlinkedEnvelopes.isNotEmpty) {
      final envelopeIds = unlinkedEnvelopes.map((e) => e.id).toList();
      await _envelopeRepo.bulkLinkToAccount(envelopeIds, defaultAccount.id);
    }
  }

  // ======================= PRIVATE HELPERS =======================

  Future<void> _unsetOtherDefaults({String? excludeAccountId}) async {
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
  }
}
