// lib/services/account_repo.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('[AccountRepo] ⚠️ Already disposed, skipping');
      return;
    }

    debugPrint('[AccountRepo] 🔄 Disposing (local-only repo, no active streams)');
    _disposed = true;
    debugPrint('[AccountRepo] ✅ Disposed');
  }

  // ======================= STREAMS =======================

  /// Accounts stream (ALWAYS local only)
  Stream<List<Account>> accountsStream() {
    // GUARD: Return empty stream if user is not authenticated (during logout)
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('[AccountRepo] ⚠️ No authenticated user - returning empty stream');
      return Stream.value([]);
    }

    debugPrint('[AccountRepo] 📦 Streaming accounts from Hive (local only)');
    debugPrint('[AccountRepo] 🔑 Current userId: $_userId');
    debugPrint('[AccountRepo] 📊 Total accounts in box: ${_accountBox.length}');

    final allAccounts = _accountBox.values.toList();
    for (final acc in allAccounts) {
      debugPrint('[AccountRepo]    - Account: ${acc.name}, userId: ${acc.userId}');
    }

    final initial = _accountBox.values
        .where((account) => account.userId == _userId)
        .toList();

    debugPrint('[AccountRepo] 📊 Initial accounts count (filtered): ${initial.length}');

    // Use Stream.multi() to ensure initial value is reliably emitted
    return Stream<List<Account>>.multi((controller) {
      // Emit initial value immediately
      controller.add(initial);
      debugPrint('[AccountRepo] ✅ Initial accounts emitted to stream');

      // Listen to box changes
      final subscription = _accountBox.watch().listen((_) {
        final accounts = _accountBox.values
            .where((account) => account.userId == _userId)
            .toList();
        debugPrint('[AccountRepo] 🔄 Accounts updated: ${accounts.length}');
        controller.add(accounts);
      });

      // Clean up when stream is cancelled
      controller.onCancel = () {
        debugPrint('[AccountRepo] 🔄 Stream cancelled, cleaning up');
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
    bool payDayAutoFillEnabled = false,
    double? payDayAutoFillAmount,
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
      iconType: iconType,
      iconValue: iconValue,
      iconColor: iconColor,
      accountType: accountType,
      creditLimit: creditLimit,
      payDayAutoFillEnabled: isDefault ? false : payDayAutoFillEnabled, // Never auto-fill default account
      payDayAutoFillAmount: isDefault ? null : payDayAutoFillAmount,
    );

    await _accountBox.put(id, account);
    debugPrint('[AccountRepo] ✅ Account created in Hive: $name');

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
    bool? payDayAutoFillEnabled,
    double? payDayAutoFillAmount,
  }) async {
    if (isDefault == true) {
      await _unsetOtherDefaults(excludeAccountId: accountId);
    }

    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

    final finalIsDefault = isDefault ?? account.isDefault;

    // For pay day auto-fill fields, we need to handle explicit updates differently
    // If both parameters are provided (even as false/null), use them
    // Otherwise, keep existing values
    bool finalPayDayAutoFillEnabled;
    double? finalPayDayAutoFillAmount;

    if (finalIsDefault) {
      // Default accounts can never have auto-fill
      finalPayDayAutoFillEnabled = false;
      finalPayDayAutoFillAmount = null;
    } else if (payDayAutoFillEnabled != null) {
      // Explicit update to auto-fill settings
      finalPayDayAutoFillEnabled = payDayAutoFillEnabled;
      // If enabling auto-fill, use provided amount (or keep existing if not provided)
      // If disabling auto-fill, clear the amount
      finalPayDayAutoFillAmount = payDayAutoFillEnabled
          ? (payDayAutoFillAmount ?? account.payDayAutoFillAmount)
          : null;
    } else {
      // No update to auto-fill settings, keep existing
      finalPayDayAutoFillEnabled = account.payDayAutoFillEnabled;
      finalPayDayAutoFillAmount = account.payDayAutoFillAmount;
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
      isDefault: finalIsDefault,
      isShared: account.isShared,
      iconType: iconType ?? account.iconType,
      iconValue: iconValue ?? account.iconValue,
      iconColor: iconColor ?? account.iconColor,
      accountType: account.accountType,
      creditLimit: account.creditLimit,
      payDayAutoFillEnabled: finalPayDayAutoFillEnabled,
      payDayAutoFillAmount: finalPayDayAutoFillAmount,
    );

    await _accountBox.put(accountId, updatedAccount);
    debugPrint('[AccountRepo] ✅ Account updated in Hive: $accountId');
    debugPrint('[AccountRepo]    payDayAutoFillEnabled: $finalPayDayAutoFillEnabled');
    debugPrint('[AccountRepo]    payDayAutoFillAmount: $finalPayDayAutoFillAmount');

    // CRITICAL: Sync to Firebase to prevent data loss
    _syncManager.pushAccount(updatedAccount, _userId);
  }

  /// Delete account
  Future<void> deleteAccount(String accountId) async {
    final account = _accountBox.get(accountId);
    if (account == null) {
      throw Exception('Account not found: $accountId');
    }

    // Prevent deletion of default account
    if (account.isDefault) {
      throw Exception(
        'Cannot delete the default account. Please set another account as default first.',
      );
    }

    // Get linked envelopes and unlink them (don't delete them)
    final linkedEnvelopes = await getLinkedEnvelopes(accountId);

    if (linkedEnvelopes.isNotEmpty) {
      debugPrint('[AccountRepo] 🔗 Unlinking ${linkedEnvelopes.length} envelope(s) from account: $accountId');

      for (final envelope in linkedEnvelopes) {
        debugPrint('[AccountRepo]    - Unlinking envelope: ${envelope.name}');
        await _envelopeRepo.updateEnvelope(
          envelopeId: envelope.id,
          linkedAccountId: null,
          updateLinkedAccountId: true,
        );
      }

      debugPrint('[AccountRepo] ✅ All envelopes unlinked');
    }

    await _accountBox.delete(accountId);
    debugPrint('[AccountRepo] ✅ Account deleted from Hive: $accountId');

    // CRITICAL: Sync deletion to Firebase to prevent data loss
    _syncManager.deleteAccount(accountId, _userId);
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
    debugPrint('[AccountRepo] ✅ Balance adjusted in Hive: ${amount > 0 ? '+' : ''}\$$amount');

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
    debugPrint('[AccountRepo] ✅ Balance set in Hive: \$$newBalance');

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
    debugPrint('[AccountRepo::getAssignedAmount] ═══════════════════════════════════════');
    debugPrint('[AccountRepo::getAssignedAmount] Calculating for account: $accountId');
    debugPrint('[AccountRepo::getAssignedAmount] Found ${linkedEnvelopes.length} linked envelopes');

    double total = 0.0;
    for (final envelope in linkedEnvelopes) {
      debugPrint('[AccountRepo::getAssignedAmount]   - ${envelope.name}:');
      debugPrint('[AccountRepo::getAssignedAmount]     • Auto-fill enabled: ${envelope.autoFillEnabled}');
      debugPrint('[AccountRepo::getAssignedAmount]     • Auto-fill amount: ${envelope.autoFillAmount}');
      debugPrint('[AccountRepo::getAssignedAmount]     • Current amount: ${envelope.currentAmount}');

      // CRITICAL FIX: Use autoFillAmount (what's ALLOCATED), not currentAmount (what's IN the envelope)
      // This shows how much of the account balance is committed to auto-fill on next pay day
      if (envelope.autoFillEnabled && envelope.autoFillAmount != null) {
        total += envelope.autoFillAmount!;
        debugPrint('[AccountRepo::getAssignedAmount]     ✅ Added ${envelope.autoFillAmount} to total');
      } else {
        debugPrint('[AccountRepo::getAssignedAmount]     ⏭️ Skipped (auto-fill disabled or no amount)');
      }
    }

    // Add account auto-fills if this is the default pay day account
    final payDaySettingsBox = Hive.box<PayDaySettings>('payDaySettings');
    final payDaySettings = payDaySettingsBox.get(_userId);

    if (payDaySettings?.defaultAccountId == accountId) {
      debugPrint('[AccountRepo::getAssignedAmount] This is the default pay day account');
      debugPrint('[AccountRepo::getAssignedAmount] Checking for account auto-fills...');

      final allAccounts = _accountBox.values
          .where((account) => account.userId == _userId)
          .toList();

      debugPrint('[AccountRepo::getAssignedAmount] Found ${allAccounts.length} accounts to check');
      for (final account in allAccounts) {
        debugPrint('[AccountRepo::getAssignedAmount]   Checking "${account.name}":');
        debugPrint('[AccountRepo::getAssignedAmount]     payDayAutoFillEnabled: ${account.payDayAutoFillEnabled}');
        debugPrint('[AccountRepo::getAssignedAmount]     payDayAutoFillAmount: ${account.payDayAutoFillAmount}');

        if (account.payDayAutoFillEnabled &&
            account.payDayAutoFillAmount != null &&
            account.payDayAutoFillAmount! > 0) {
          total += account.payDayAutoFillAmount!;
          debugPrint('[AccountRepo::getAssignedAmount]   + Account "${account.name}" auto-fill: ${account.payDayAutoFillAmount}');
        } else {
          debugPrint('[AccountRepo::getAssignedAmount]   ⏭️ Skipped "${account.name}"');
        }
      }
    }

    debugPrint('[AccountRepo::getAssignedAmount] 📊 Total assigned: $total');
    debugPrint('[AccountRepo::getAssignedAmount] ═══════════════════════════════════════');
    return total;
  }

  /// Stream the assigned amount for an account (updates when envelopes or accounts change)
  Stream<double> assignedAmountStream(String accountId) {
    // Combine envelope and account streams to update when either changes
    return Rx.combineLatest2(
      _envelopeRepo.envelopesStream(),
      accountsStream(),
      (envelopes, accounts) => (envelopes, accounts),
    ).asyncMap((data) async {
      final envelopes = data.$1;
      final accounts = data.$2;
      final linkedEnvelopes = envelopes.where((env) => env.linkedAccountId == accountId).toList();

      debugPrint('[AccountRepo::assignedAmountStream] ═══════════════════════════════════════');
      debugPrint('[AccountRepo::assignedAmountStream] Calculating for account: $accountId');
      debugPrint('[AccountRepo::assignedAmountStream] Found ${linkedEnvelopes.length} linked envelopes');

      double total = 0.0;
      for (final envelope in linkedEnvelopes) {
        debugPrint('[AccountRepo::assignedAmountStream]   - ${envelope.name}:');
        debugPrint('[AccountRepo::assignedAmountStream]     • Auto-fill enabled: ${envelope.autoFillEnabled}');
        debugPrint('[AccountRepo::assignedAmountStream]     • Auto-fill amount: ${envelope.autoFillAmount}');

        if (envelope.autoFillEnabled && envelope.autoFillAmount != null) {
          total += envelope.autoFillAmount!;
          debugPrint('[AccountRepo::assignedAmountStream]     ✅ Added ${envelope.autoFillAmount} to total');
        } else {
          debugPrint('[AccountRepo::assignedAmountStream]     ⏭️ Skipped');
        }
      }

      // Add account auto-fills if this is the default pay day account
      final payDaySettingsBox = Hive.box<PayDaySettings>('payDaySettings');
      final payDaySettings = payDaySettingsBox.get(_userId);

      if (payDaySettings?.defaultAccountId == accountId) {
        debugPrint('[AccountRepo::assignedAmountStream] This is the default pay day account');
        debugPrint('[AccountRepo::assignedAmountStream] Checking for account auto-fills...');
        debugPrint('[AccountRepo::assignedAmountStream] Found ${accounts.length} accounts to check');

        for (final account in accounts) {
          debugPrint('[AccountRepo::assignedAmountStream]   Checking "${account.name}":');
          debugPrint('[AccountRepo::assignedAmountStream]     payDayAutoFillEnabled: ${account.payDayAutoFillEnabled}');
          debugPrint('[AccountRepo::assignedAmountStream]     payDayAutoFillAmount: ${account.payDayAutoFillAmount}');

          if (account.payDayAutoFillEnabled &&
              account.payDayAutoFillAmount != null &&
              account.payDayAutoFillAmount! > 0) {
            total += account.payDayAutoFillAmount!;
            debugPrint('[AccountRepo::assignedAmountStream]   + Account "${account.name}" auto-fill: ${account.payDayAutoFillAmount}');
          } else {
            debugPrint('[AccountRepo::assignedAmountStream]   ⏭️ Skipped "${account.name}"');
          }
        }
      }

      debugPrint('[AccountRepo::assignedAmountStream] 📊 Total assigned: $total');
      debugPrint('[AccountRepo::assignedAmountStream] ═══════════════════════════════════════');
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
    debugPrint('[AccountRepo] ✅ Unset other defaults in Hive');
  }
}
