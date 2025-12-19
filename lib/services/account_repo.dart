// lib/services/account_repo.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../models/account.dart';
import '../models/envelope.dart';
import 'envelope_repo.dart';

class AccountRepo {
  AccountRepo(this._db, this._envelopeRepo);

  final fs.FirebaseFirestore _db;
  final EnvelopeRepo _envelopeRepo;

  String get _userId => _envelopeRepo.currentUserId;
  bool get _inWorkspace => _envelopeRepo.inWorkspace;
  String? get _workspaceId => _envelopeRepo.workspaceId;

  // --------- Collection References ----------

  fs.CollectionReference<Map<String, dynamic>> _accountsCol() {
    if (_inWorkspace && _workspaceId != null) {
      return _db
          .collection('workspaces')
          .doc(_workspaceId)
          .collection('accounts');
    } else {
      return _db
          .collection('users')
          .doc(_userId)
          .collection('solo')
          .doc('data')
          .collection('accounts');
    }
  }

  // --------- Streams ----------

  Stream<List<Account>> accountsStream() {
    return _accountsCol()
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList(),
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
  }) async {
    final doc = _accountsCol().doc();

    if (isDefault) {
      await _unsetOtherDefaults();
    }

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
    });

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
      await _unsetOtherDefaults(excludeAccountId: accountId);
      updateData['isDefault'] = true;
    } else if (isDefault == false) {
      updateData['isDefault'] = false;
    }

    await _accountsCol().doc(accountId).update(updateData);
  }

  Future<void> deleteAccount(String accountId) async {
    final linkedEnvelopes = await getLinkedEnvelopes(accountId);

    if (linkedEnvelopes.isNotEmpty) {
      throw Exception(
        'Cannot delete account with linked envelopes. Please unlink or delete ${linkedEnvelopes.length} envelope(s) first.',
      );
    }

    await _accountsCol().doc(accountId).delete();
  }

  Future<void> adjustBalance({
    required String accountId,
    required double amount,
  }) async {
    await _accountsCol().doc(accountId).update({
      'currentBalance': fs.FieldValue.increment(amount),
      'lastUpdated': fs.FieldValue.serverTimestamp(),
    });
  }

  Future<void> setBalance({
    required String accountId,
    required double newBalance,
  }) async {
    await _accountsCol().doc(accountId).update({
      'currentBalance': newBalance,
      'lastUpdated': fs.FieldValue.serverTimestamp(),
    });
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
  }
}
