// lib/services/account_repo.dart
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/account.dart';
import '../models/envelope.dart';
import 'envelope_repo.dart';
import 'hive_service.dart';

/// Account repository - PURE HIVE (No Firebase sync)
///
/// Accounts are ALWAYS local-only, even in workspace mode.
/// They are never synced to Firebase or shared with workspace partners.
class AccountRepo {
  AccountRepo(this._envelopeRepo) {
    _accountBox = HiveService.getBox<Account>('accounts');
  }

  final EnvelopeRepo _envelopeRepo;
  late final Box<Account> _accountBox;

  String get _userId => _envelopeRepo.currentUserId;

  // ======================= STREAMS =======================

  /// Accounts stream (ALWAYS local only)
  Stream<List<Account>> accountsStream() {
    debugPrint('[AccountRepo] 📦 Streaming accounts from Hive (local only)');

    final initial = _accountBox.values
        .where((account) => account.userId == _userId)
        .toList();

    return Stream.value(initial).asBroadcastStream().concatWith([
      _accountBox.watch().map((_) {
        return _accountBox.values
            .where((account) => account.userId == _userId)
            .toList();
      })
    ]);
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
      iconType: iconType,
      iconValue: iconValue,
      iconColor: iconColor,
      accountType: accountType,
      creditLimit: creditLimit,
    );

    await _accountBox.put(id, account);
    debugPrint('[AccountRepo] ✅ Account created in Hive: $name');

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
    debugPrint('[AccountRepo] ✅ Account updated in Hive: $accountId');
  }

  /// Delete account
  Future<void> deleteAccount(String accountId) async {
    // Check for linked envelopes - prevent deletion if any exist
    final linkedEnvelopes = await getLinkedEnvelopes(accountId);

    if (linkedEnvelopes.isNotEmpty) {
      throw Exception(
        'Cannot delete account with linked envelopes. Please unlink or delete ${linkedEnvelopes.length} envelope(s) first.',
      );
    }

    await _accountBox.delete(accountId);
    debugPrint('[AccountRepo] ✅ Account deleted from Hive: $accountId');
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
      total += envelope.currentAmount;
    }
    return total;
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
